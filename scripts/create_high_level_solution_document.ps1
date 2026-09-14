$ErrorActionPreference = "Stop"

$sourcePath = Join-Path $PSScriptRoot "..\Amazon_Connect_Routing_Profile_Manager_High_Level_Costing.docx"
$sourcePath = [System.IO.Path]::GetFullPath($sourcePath)
$outputPath = Join-Path $PSScriptRoot "..\Amazon_Connect_Routing_Profile_Manager_High_Level_Solution.docx"
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
    @("User workspace", "Amazon Connect Agent Workspace", "Hosts the embedded application used by the agent."),
    @("Frontend", "React application", "Displays the current routing profile, available profiles, and the profile-change action."),
    @("Content delivery", "Amazon CloudFront", "Delivers the frontend application to the agent browser."),
    @("Frontend storage", "Amazon S3", "Stores the compiled React application files."),
    @("Workspace integration", "Amazon Connect Agent Client", "Provides the current agent ARN and current routing-profile details to the frontend."),
    @("Application endpoint", "Lambda Function URL", "Receives profile-list and profile-update requests directly from the browser."),
    @("Backend", "AWS Lambda", "Lists routing profiles and processes the selected routing-profile change."),
    @("Contact-centre service", "Amazon Connect API", "Returns routing profiles and updates the Connect user configuration."),
    @("AWS permissions", "AWS IAM", "Allows Lambda to list routing profiles and call UpdateUserRoutingProfile."),
    @("Application logging", "Amazon CloudWatch Logs", "Stores the standard Lambda execution and application log entries.")
)

$flowRows = @(
    @("1", "Open application", "The agent opens the routing profile manager inside the Amazon Connect Agent Workspace."),
    @("2", "Read agent details", "The frontend obtains the current agent ARN and routing profile from the Amazon Connect Agent Client."),
    @("3", "Load profiles", "The browser calls the Lambda Function URL and Lambda retrieves the routing profiles from Amazon Connect."),
    @("4", "Select profile", "The agent selects an available routing profile from the application."),
    @("5", "Submit change", "The browser sends the agent ARN and selected routing-profile ID to Lambda."),
    @("6", "Apply change", "Lambda extracts the Connect user ID and calls UpdateUserRoutingProfile."),
    @("7", "Show result", "The application displays confirmation and refreshes the agent's current routing-profile information.")
)

$deploymentRows = @(
    @("1", "Backend", "Upload the Lambda ZIP and create the CloudFormation stack in the Amazon Connect Region."),
    @("2", "Endpoint", "Copy the Lambda Function URL created by CloudFormation."),
    @("3", "Frontend", "Set REACT_APP_API_BASE_URL to the Function URL and create the React build."),
    @("4", "Hosting", "Upload the build files to S3 and invalidate the CloudFront distribution."),
    @("5", "Connect", "Register the CloudFront URL as a third-party application and add the required workspace permissions."),
    @("6", "Pilot", "Assign the application to a test agent and validate the complete routing-profile change flow.")
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
  <w:r><w:rPr><w:color w:val="595959"/><w:sz w:val="22"/></w:rPr><w:t>High-Level Solution Overview</w:t></w:r>
</w:p>
'@)

[void]$bodyBuilder.Append((New-SectionHeading "Solution Overview"))
[void]$bodyBuilder.Append((New-NormalParagraph -Text "The Routing Profile Manager is a small application embedded in the Amazon Connect Agent Workspace. It allows an agent to view their current routing profile, select another available routing profile, and apply the change without leaving the workspace."))

[void]$bodyBuilder.Append((New-SectionHeading "Business Purpose"))
[void]$bodyBuilder.Append((New-Bullet "Provide agents with a simple self-service routing-profile change experience."))
[void]$bodyBuilder.Append((New-Bullet "Reduce the need for an administrator to perform routine profile changes manually."))
[void]$bodyBuilder.Append((New-Bullet "Keep the activity inside the existing Amazon Connect Agent Workspace."))
[void]$bodyBuilder.Append((New-Bullet "Use AWS managed services and a small serverless backend."))

[void]$bodyBuilder.Append((New-SectionHeading "Current Capabilities"))
[void]$bodyBuilder.Append((New-Bullet "Display the signed-in Connect agent's current routing profile."))
[void]$bodyBuilder.Append((New-Bullet "Retrieve and display the routing profiles available in the Connect instance."))
[void]$bodyBuilder.Append((New-Bullet "Allow the agent to select and apply a routing profile."))
[void]$bodyBuilder.Append((New-Bullet "Display a success or error message after the request."))
[void]$bodyBuilder.Append((New-Bullet "Refresh the displayed profile when Amazon Connect reports a routing-profile change."))

[void]$bodyBuilder.Append((New-SectionHeading "High-Level Architecture"))
[void]$bodyBuilder.Append((New-NormalParagraph -Text "Amazon Connect Agent Workspace  >  CloudFront / S3  >  Lambda Function URL  >  AWS Lambda  >  Amazon Connect API" -Bold -Center -Color "1F4E79" -Size 20 -After 140))

[void]$bodyBuilder.Append((New-SectionHeading "Solution Components"))
[void]$bodyBuilder.Append((New-Table -Widths @(1900, 2700, 5336) -Headers @("Component", "AWS Service / Technology", "Purpose") -Rows $componentRows))

[void]$bodyBuilder.Append('<w:p><w:r><w:br w:type="page"/></w:r></w:p>')

[void]$bodyBuilder.Append((New-SectionHeading "Application Flow"))
[void]$bodyBuilder.Append((New-Table -Widths @(700, 2200, 7036) -Headers @("Step", "Activity", "Description") -Rows $flowRows))

[void]$bodyBuilder.Append((New-SectionHeading "Amazon Connect Configuration"))
[void]$bodyBuilder.Append((New-Bullet "Register the CloudFront address as an Amazon Connect third-party application."))
[void]$bodyBuilder.Append((New-Bullet "Grant User.Details.View so the application can obtain the current agent ARN."))
[void]$bodyBuilder.Append((New-Bullet "Grant User.Configuration.View so the application can read the current routing profile."))
[void]$bodyBuilder.Append((New-Bullet "Assign the third-party application to the required Amazon Connect security profiles."))

[void]$bodyBuilder.Append((New-SectionHeading "High-Level Deployment"))
[void]$bodyBuilder.Append((New-Table -Widths @(700, 2200, 7036) -Headers @("Step", "Area", "Action") -Rows $deploymentRows))

[void]$bodyBuilder.Append((New-SectionHeading "Current Scope and Considerations"))
[void]$bodyBuilder.Append((New-Bullet "Application visibility is controlled through the Amazon Connect security profiles assigned to the third-party application."))
[void]$bodyBuilder.Append((New-Bullet "The current backend returns all routing profiles in the configured Amazon Connect instance."))
[void]$bodyBuilder.Append((New-Bullet "The current implementation does not contain source-to-destination routing-profile rules, approvals, scheduling, or automatic profile reversion."))
[void]$bodyBuilder.Append((New-Bullet "The Lambda Function URL currently uses the open test configuration and the browser supplies the Connect agent ARN."))
[void]$bodyBuilder.Append((New-Bullet "Agent eligibility, allowed routing profiles, production security, audit requirements, monitoring, and support ownership should be confirmed before production rollout."))

[void]$bodyBuilder.Append((New-SectionHeading "Key Client Decisions"))
[void]$bodyBuilder.Append((New-Bullet "Which agents, teams, and Amazon Connect security profiles should use the application?"))
[void]$bodyBuilder.Append((New-Bullet "Which routing profiles should be available, and are specific profile transitions required?"))
[void]$bodyBuilder.Append((New-Bullet "Should agents change only their own profile, or should supervisors manage other agents?"))
[void]$bodyBuilder.Append((New-Bullet "What production authentication, network access, audit logging, and operational controls are required?"))

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
  <dc:title>Amazon Connect Routing Profile Manager - High-Level Solution Overview</dc:title>
  <dc:subject>High-level application purpose, architecture, components, and deployment</dc:subject>
  <dc:creator>OpenAI</dc:creator>
  <cp:keywords>Amazon Connect, routing profile, CloudFront, S3, Lambda Function URL, Lambda</cp:keywords>
  <dc:description>High-level solution overview for the Amazon Connect routing profile manager.</dc:description>
  <cp:lastModifiedBy>OpenAI</cp:lastModifiedBy>
  <cp:revision>1</cp:revision>
  <dcterms:created xsi:type="dcterms:W3CDTF">$modifiedUtc</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">$modifiedUtc</dcterms:modified>
</cp:coreProperties>
"@

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
