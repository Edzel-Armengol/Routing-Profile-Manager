$ErrorActionPreference = "Stop"

$sourcePath = "C:\Users\EdzelArmengol\Downloads\Amazon_Connect_Queue_Prioritization_Costing.docx"
$outputPath = Join-Path $PSScriptRoot "..\Amazon_Connect_Routing_Profile_Manager_Infrastructure_and_Deployment.docx"
$outputPath = [System.IO.Path]::GetFullPath($outputPath)

Add-Type -AssemblyName System.IO.Compression

function ConvertTo-XmlText {
    param([string]$Value)
    return [System.Security.SecurityElement]::Escape($Value)
}

function New-SectionHeading {
    param([string]$Text)
    $safeText = ConvertTo-XmlText $Text
    return "<w:p><w:pPr><w:pStyle w:val=`"SectionLabel`"/></w:pPr><w:r><w:t>$safeText</w:t></w:r></w:p>"
}

function New-NormalParagraph {
    param(
        [string]$Text,
        [switch]$Bold,
        [switch]$Center,
        [string]$Color = "",
        [int]$Size = 20,
        [int]$Before = 0,
        [int]$After = 100
    )
    $safeText = ConvertTo-XmlText $Text
    $boldXml = if ($Bold) { "<w:b/>" } else { "" }
    $centerXml = if ($Center) { "<w:jc w:val=`"center`"/>" } else { "" }
    $colorXml = if ($Color) { "<w:color w:val=`"$Color`"/>" } else { "" }
    return "<w:p><w:pPr><w:spacing w:before=`"$Before`" w:after=`"$After`"/>$centerXml</w:pPr><w:r><w:rPr>$boldXml$colorXml<w:sz w:val=`"$Size`"/></w:rPr><w:t>$safeText</w:t></w:r></w:p>"
}

function New-Bullet {
    param([string]$Text)
    $safeText = ConvertTo-XmlText $Text
    return "<w:p><w:pPr><w:pStyle w:val=`"ListBullet`"/><w:spacing w:after=`"40`"/><w:ind w:hanging=`"216`"/></w:pPr><w:r><w:t>$safeText</w:t></w:r></w:p>"
}

function New-TableCell {
    param(
        [string]$Text,
        [int]$Width,
        [ValidateSet("Header", "Label", "Body")]
        [string]$Type = "Body"
    )
    $safeText = ConvertTo-XmlText $Text
    $fillXml = ""
    $runXml = "<w:sz w:val=`"19`"/>"
    $alignmentXml = ""

    if ($Type -eq "Header") {
        $fillXml = "<w:shd w:val=`"clear`" w:fill=`"1F4E79`"/>"
        $runXml = "<w:b/><w:color w:val=`"FFFFFF`"/><w:sz w:val=`"19`"/>"
        $alignmentXml = "<w:jc w:val=`"center`"/>"
    }
    elseif ($Type -eq "Label") {
        $fillXml = "<w:shd w:val=`"clear`" w:fill=`"D9EAF7`"/>"
        $runXml = "<w:b/><w:color w:val=`"1F4E79`"/><w:sz w:val=`"19`"/>"
    }

    return @"
<w:tc>
  <w:tcPr>
    <w:tcW w:w="$Width" w:type="dxa"/>
    $fillXml
    <w:tcMar>
      <w:top w:w="115" w:type="dxa"/><w:left w:w="120" w:type="dxa"/>
      <w:bottom w:w="115" w:type="dxa"/><w:right w:w="120" w:type="dxa"/>
    </w:tcMar>
    <w:vAlign w:val="center"/>
  </w:tcPr>
  <w:p>
    <w:pPr><w:spacing w:after="0"/>$alignmentXml</w:pPr>
    <w:r><w:rPr>$runXml</w:rPr><w:t>$safeText</w:t></w:r>
  </w:p>
</w:tc>
"@
}

function New-Table {
    param(
        [int[]]$Widths,
        [string[]]$Headers,
        [object[]]$Rows,
        [switch]$FirstColumnLabels
    )

    $grid = ($Widths | ForEach-Object { "<w:gridCol w:w=`"$_`"/>" }) -join ""
    $builder = [System.Text.StringBuilder]::new()
    [void]$builder.Append(@"
<w:tbl>
  <w:tblPr>
    <w:tblStyle w:val="TableGrid"/>
    <w:tblW w:w="0" w:type="auto"/>
    <w:jc w:val="center"/>
    <w:tblLayout w:type="fixed"/>
    <w:tblLook w:val="04A0" w:firstRow="1" w:lastRow="0" w:firstColumn="1" w:lastColumn="0" w:noHBand="0" w:noVBand="1"/>
  </w:tblPr>
  <w:tblGrid>$grid</w:tblGrid>
"@)

    if ($Headers.Count -gt 0) {
        [void]$builder.Append("<w:tr><w:trPr><w:tblHeader/><w:cantSplit/></w:trPr>")
        for ($i = 0; $i -lt $Headers.Count; $i++) {
            [void]$builder.Append((New-TableCell -Text $Headers[$i] -Width $Widths[$i] -Type "Header"))
        }
        [void]$builder.Append("</w:tr>")
    }

    foreach ($row in $Rows) {
        [void]$builder.Append("<w:tr><w:trPr><w:cantSplit/></w:trPr>")
        for ($i = 0; $i -lt $row.Count; $i++) {
            $cellType = if ($FirstColumnLabels -and $i -eq 0) { "Label" } else { "Body" }
            [void]$builder.Append((New-TableCell -Text ([string]$row[$i]) -Width $Widths[$i] -Type $cellType))
        }
        [void]$builder.Append("</w:tr>")
    }

    [void]$builder.Append("</w:tbl>")
    return $builder.ToString()
}

$componentRows = @(
    @("Agent experience", "Amazon Connect Agent Workspace", "Displays the routing profile manager and provides the current agent details."),
    @("Frontend", "CloudFront + Amazon S3", "Hosts and delivers the React application."),
    @("Endpoint", "Lambda Function URL", "Receives routing-profile list and update requests directly from the browser."),
    @("Backend", "AWS Lambda", "Lists routing profiles and calls the Amazon Connect API to update the selected agent."),
    @("Contact centre", "Amazon Connect", "Stores the agents, queues, and routing-profile configuration.")
)

$environmentRows = @(
    @("AWS Region", "ap-southeast-2"),
    @("CloudFront domain", "https://d185fem9nj1anr.cloudfront.net"),
    @("CloudFront distribution", "E3MQT8G52R0UJO"),
    @("Frontend S3 bucket", "custom-agent-workspace-s3bucketforwebsitecontent-qsnyiqgvgsnt"),
    @("Connect instance ID", "eefde7f8-7534-4dac-a433-f5a922235cc5")
)

$responsibilityRows = @(
    @("Client Connect administrator", "Provide the Connect instance details and make the application available to the required test agents."),
    @("Client AWS administrator", "Provide access to S3, Lambda, CloudFormation, and CloudFront in the test account."),
    @("Deployment team", "Deploy the Lambda backend, publish the frontend, configure the Connect integration, and perform the pilot.")
)

$deploymentRows = @(
    @("1", "Upload backend package", "In the ap-southeast-2 S3 console, upload routing-profile-function.zip to a deployment bucket."),
    @("2", "Create AWS stack", "In the CloudFormation console, upload template.yaml, enter the code bucket and Connect instance ID, and create the stack."),
    @("3", "Record endpoint", "Copy the FunctionUrl value from the CloudFormation stack outputs."),
    @("4", "Prepare frontend", "Set REACT_APP_API_BASE_URL to the Function URL and produce the React build."),
    @("5", "Publish frontend", "Upload the build contents to the S3 frontend bucket and create a CloudFront invalidation for /*."),
    @("6", "Configure Connect app", "Set the CloudFront access URL, add the required workspace permissions, and assign the application to the test agent."),
    @("7", "Pilot and validate", "Confirm the current profile loads, the profile list appears, and a selected profile can be applied.")
)

$bodyBuilder = [System.Text.StringBuilder]::new()

[void]$bodyBuilder.Append(@'
<w:p>
  <w:pPr><w:spacing w:after="40"/><w:jc w:val="center"/></w:pPr>
  <w:r>
    <w:rPr><w:rFonts w:ascii="Aptos Display" w:hAnsi="Aptos Display"/><w:b/><w:color w:val="1F4E79"/><w:sz w:val="36"/></w:rPr>
    <w:t>Amazon Connect &#x2013; Routing Profile Manager</w:t>
  </w:r>
</w:p>
<w:p>
  <w:pPr><w:spacing w:after="280"/><w:jc w:val="center"/></w:pPr>
  <w:r><w:rPr><w:color w:val="595959"/><w:sz w:val="22"/></w:rPr><w:t>High-Level Infrastructure and Deployment Process</w:t></w:r>
</w:p>
<w:p>
  <w:pPr><w:pStyle w:val="SectionLabel"/></w:pPr>
  <w:r><w:rPr><w:rFonts w:ascii="Aptos" w:hAnsi="Aptos"/><w:sz w:val="21"/></w:rPr>
    <w:t>The solution provides an application inside the Amazon Connect Agent Workspace that allows an agent to view and change their routing profile.</w:t>
  </w:r>
</w:p>
'@)

[void]$bodyBuilder.Append((New-SectionHeading "Architecture Flow"))
[void]$bodyBuilder.Append((New-NormalParagraph -Text "Amazon Connect Workspace  >  CloudFront / S3  >  Lambda Function URL  >  Lambda  >  Amazon Connect" -Bold -Center -Color "1F4E79" -Size 20 -After 140))

[void]$bodyBuilder.Append((New-SectionHeading "Infrastructure Components"))
[void]$bodyBuilder.Append((New-Table -Widths @(1800, 2800, 5336) -Headers @("Layer", "Service", "Responsibility") -Rows $componentRows))

[void]$bodyBuilder.Append((New-SectionHeading "Existing Environment"))
[void]$bodyBuilder.Append((New-Table -Widths @(3240, 6696) -Headers @() -Rows $environmentRows -FirstColumnLabels))

[void]$bodyBuilder.Append('<w:p><w:r><w:br w:type="page"/></w:r></w:p>')

[void]$bodyBuilder.Append((New-SectionHeading "Deployment Responsibilities"))
[void]$bodyBuilder.Append((New-Table -Widths @(3240, 6696) -Headers @("Owner", "Responsibility") -Rows $responsibilityRows))

[void]$bodyBuilder.Append((New-SectionHeading "Required Deployment Inputs"))
[void]$bodyBuilder.Append((New-Bullet "Amazon Connect instance ID and test agent details."))
[void]$bodyBuilder.Append((New-Bullet "Lambda deployment ZIP and the CloudFormation template."))
[void]$bodyBuilder.Append((New-Bullet "CloudFront distribution and S3 frontend bucket."))
[void]$bodyBuilder.Append((New-Bullet "AWS console access to S3, CloudFormation, CloudFront, Lambda, and Amazon Connect."))

[void]$bodyBuilder.Append((New-SectionHeading "Deployment Process"))
[void]$bodyBuilder.Append((New-Table -Widths @(700, 2300, 6936) -Headers @("Step", "Activity", "High-Level Action") -Rows $deploymentRows))

[void]$bodyBuilder.Append((New-SectionHeading "Pilot Validation"))
[void]$bodyBuilder.Append((New-Bullet "The application loads inside the Amazon Connect Agent Workspace."))
[void]$bodyBuilder.Append((New-Bullet "The current agent routing profile is displayed."))
[void]$bodyBuilder.Append((New-Bullet "The available routing profiles are returned by Lambda."))
[void]$bodyBuilder.Append((New-Bullet "A selected routing profile is applied to the test agent."))

[void]$bodyBuilder.Append((New-SectionHeading "Rollback"))
[void]$bodyBuilder.Append((New-NormalParagraph -Text "Keep a copy of the previous frontend build. If the pilot fails, restore the previous S3 files and create a CloudFront invalidation." -After 0))

$bodyXml = $bodyBuilder.ToString()
$documentXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document
    xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
    xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:body>
    $bodyXml
    <w:sectPr>
      <w:footerReference w:type="default" r:id="rId8"/>
      <w:pgSz w:w="12240" w:h="15840"/>
      <w:pgMar w:top="936" w:right="1080" w:bottom="936" w:left="1080" w:header="720" w:footer="720" w:gutter="0"/>
      <w:cols w:space="720"/>
      <w:docGrid w:linePitch="360"/>
    </w:sectPr>
  </w:body>
</w:document>
"@

$modifiedUtc = [System.DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
$coreXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties
    xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:dcterms="http://purl.org/dc/terms/"
    xmlns:dcmitype="http://purl.org/dc/dcmitype/"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>Amazon Connect Routing Profile Manager - Infrastructure and Deployment</dc:title>
  <dc:subject>High-level infrastructure and console deployment process</dc:subject>
  <dc:creator>OpenAI</dc:creator>
  <cp:keywords>Amazon Connect, Lambda Function URL, Lambda, CloudFront, deployment</cp:keywords>
  <dc:description>High-level infrastructure and deployment process for the routing profile manager.</dc:description>
  <cp:lastModifiedBy>OpenAI</cp:lastModifiedBy>
  <cp:revision>1</cp:revision>
  <dcterms:created xsi:type="dcterms:W3CDTF">$modifiedUtc</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">$modifiedUtc</dcterms:modified>
</cp:coreProperties>
"@

# Copy the reference Word package while allowing Word to keep it open.
$sourceStream = [System.IO.File]::Open(
    $sourcePath,
    [System.IO.FileMode]::Open,
    [System.IO.FileAccess]::Read,
    [System.IO.FileShare]::ReadWrite
)
$outputStream = [System.IO.File]::Open(
    $outputPath,
    [System.IO.FileMode]::Create,
    [System.IO.FileAccess]::ReadWrite,
    [System.IO.FileShare]::None
)
$sourceStream.CopyTo($outputStream)
$sourceStream.Dispose()
$outputStream.Dispose()

$packageStream = [System.IO.File]::Open(
    $outputPath,
    [System.IO.FileMode]::Open,
    [System.IO.FileAccess]::ReadWrite,
    [System.IO.FileShare]::None
)
$archive = [System.IO.Compression.ZipArchive]::new(
    $packageStream,
    [System.IO.Compression.ZipArchiveMode]::Update
)

foreach ($part in @(
    @{ Name = "word/document.xml"; Content = $documentXml },
    @{ Name = "docProps/core.xml"; Content = $coreXml }
)) {
    $existingPart = $archive.GetEntry($part.Name)
    if ($existingPart) {
        $existingPart.Delete()
    }
    $newPart = $archive.CreateEntry(
        $part.Name,
        [System.IO.Compression.CompressionLevel]::Optimal
    )
    $writer = [System.IO.StreamWriter]::new(
        $newPart.Open(),
        [System.Text.UTF8Encoding]::new($false)
    )
    $writer.Write($part.Content)
    $writer.Dispose()
}

$archive.Dispose()
$packageStream.Dispose()

Write-Output $outputPath
