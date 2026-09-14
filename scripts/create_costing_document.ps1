$ErrorActionPreference = "Stop"

$sourcePath = "C:\Users\EdzelArmengol\Downloads\Amazon_Connect_Queue_Prioritization_Costing.docx"
$outputPath = Join-Path $PSScriptRoot "..\Amazon_Connect_Routing_Profile_Manager_High_Level_Costing.docx"
$outputPath = [System.IO.Path]::GetFullPath($outputPath)

Add-Type -AssemblyName System.IO.Compression

# Copy the reference package while allowing Microsoft Word to keep the source open.
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

$documentXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document
    xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
    xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:body>
    <w:p>
      <w:pPr><w:spacing w:after="40"/><w:jc w:val="center"/></w:pPr>
      <w:r>
        <w:rPr>
          <w:rFonts w:ascii="Aptos Display" w:hAnsi="Aptos Display"/>
          <w:b/><w:color w:val="1F4E79"/><w:sz w:val="36"/>
        </w:rPr>
        <w:t>Amazon Connect &#x2013; Routing Profile Manager</w:t>
      </w:r>
    </w:p>
    <w:p>
      <w:pPr><w:spacing w:after="280"/><w:jc w:val="center"/></w:pPr>
      <w:r>
        <w:rPr><w:color w:val="595959"/><w:sz w:val="22"/></w:rPr>
        <w:t>High-Level Write-Up and Costing</w:t>
      </w:r>
    </w:p>

    <w:p>
      <w:pPr><w:pStyle w:val="SectionLabel"/></w:pPr>
      <w:r>
        <w:rPr><w:rFonts w:ascii="Aptos" w:hAnsi="Aptos"/><w:sz w:val="21"/></w:rPr>
        <w:t>Provide a small application in the Amazon Connect Agent Workspace that allows agents to change their own routing profile from the available routing profiles.</w:t>
      </w:r>
    </w:p>

    <w:p>
      <w:pPr><w:pStyle w:val="SectionLabel"/></w:pPr>
      <w:r><w:t>Proposed Configuration</w:t></w:r>
    </w:p>

    <w:tbl>
      <w:tblPr>
        <w:tblStyle w:val="TableGrid"/>
        <w:tblW w:w="0" w:type="auto"/>
        <w:jc w:val="center"/>
        <w:tblLayout w:type="fixed"/>
        <w:tblLook w:val="04A0" w:firstRow="1" w:lastRow="0" w:firstColumn="1" w:lastColumn="0" w:noHBand="0" w:noVBand="1"/>
      </w:tblPr>
      <w:tblGrid>
        <w:gridCol w:w="1800"/><w:gridCol w:w="2800"/><w:gridCol w:w="5336"/>
      </w:tblGrid>
      <w:tr>
        <w:trPr><w:tblHeader/></w:trPr>
        <w:tc>
          <w:tcPr><w:tcW w:w="1800" w:type="dxa"/><w:shd w:val="clear" w:fill="1F4E79"/><w:tcMar><w:top w:w="120" w:type="dxa"/><w:left w:w="120" w:type="dxa"/><w:bottom w:w="120" w:type="dxa"/><w:right w:w="120" w:type="dxa"/></w:tcMar><w:vAlign w:val="center"/></w:tcPr>
          <w:p><w:pPr><w:spacing w:after="0"/><w:jc w:val="center"/></w:pPr><w:r><w:rPr><w:b/><w:color w:val="FFFFFF"/><w:sz w:val="19"/></w:rPr><w:t>Component</w:t></w:r></w:p>
        </w:tc>
        <w:tc>
          <w:tcPr><w:tcW w:w="2800" w:type="dxa"/><w:shd w:val="clear" w:fill="1F4E79"/><w:tcMar><w:top w:w="120" w:type="dxa"/><w:left w:w="120" w:type="dxa"/><w:bottom w:w="120" w:type="dxa"/><w:right w:w="120" w:type="dxa"/></w:tcMar><w:vAlign w:val="center"/></w:tcPr>
          <w:p><w:pPr><w:spacing w:after="0"/><w:jc w:val="center"/></w:pPr><w:r><w:rPr><w:b/><w:color w:val="FFFFFF"/><w:sz w:val="19"/></w:rPr><w:t>Service</w:t></w:r></w:p>
        </w:tc>
        <w:tc>
          <w:tcPr><w:tcW w:w="5336" w:type="dxa"/><w:shd w:val="clear" w:fill="1F4E79"/><w:tcMar><w:top w:w="120" w:type="dxa"/><w:left w:w="120" w:type="dxa"/><w:bottom w:w="120" w:type="dxa"/><w:right w:w="120" w:type="dxa"/></w:tcMar><w:vAlign w:val="center"/></w:tcPr>
          <w:p><w:pPr><w:spacing w:after="0"/><w:jc w:val="center"/></w:pPr><w:r><w:rPr><w:b/><w:color w:val="FFFFFF"/><w:sz w:val="19"/></w:rPr><w:t>Purpose</w:t></w:r></w:p>
        </w:tc>
      </w:tr>
      <w:tr>
        <w:tc><w:tcPr><w:tcW w:w="1800" w:type="dxa"/><w:tcMar><w:top w:w="110" w:type="dxa"/><w:left w:w="120" w:type="dxa"/><w:bottom w:w="110" w:type="dxa"/><w:right w:w="120" w:type="dxa"/></w:tcMar></w:tcPr><w:p><w:pPr><w:spacing w:after="0"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="19"/></w:rPr><w:t>Frontend</w:t></w:r></w:p></w:tc>
        <w:tc><w:tcPr><w:tcW w:w="2800" w:type="dxa"/><w:tcMar><w:top w:w="110" w:type="dxa"/><w:left w:w="120" w:type="dxa"/><w:bottom w:w="110" w:type="dxa"/><w:right w:w="120" w:type="dxa"/></w:tcMar></w:tcPr><w:p><w:pPr><w:spacing w:after="0"/></w:pPr><w:r><w:rPr><w:sz w:val="19"/></w:rPr><w:t>CloudFront + Amazon S3</w:t></w:r></w:p></w:tc>
        <w:tc><w:tcPr><w:tcW w:w="5336" w:type="dxa"/><w:tcMar><w:top w:w="110" w:type="dxa"/><w:left w:w="120" w:type="dxa"/><w:bottom w:w="110" w:type="dxa"/><w:right w:w="120" w:type="dxa"/></w:tcMar></w:tcPr><w:p><w:pPr><w:spacing w:after="0"/></w:pPr><w:r><w:rPr><w:sz w:val="19"/></w:rPr><w:t>Hosts the embedded agent application.</w:t></w:r></w:p></w:tc>
      </w:tr>
      <w:tr>
        <w:tc><w:tcPr><w:tcW w:w="1800" w:type="dxa"/><w:tcMar><w:top w:w="110" w:type="dxa"/><w:left w:w="120" w:type="dxa"/><w:bottom w:w="110" w:type="dxa"/><w:right w:w="120" w:type="dxa"/></w:tcMar></w:tcPr><w:p><w:pPr><w:spacing w:after="0"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="19"/></w:rPr><w:t>Backend</w:t></w:r></w:p></w:tc>
        <w:tc><w:tcPr><w:tcW w:w="2800" w:type="dxa"/><w:tcMar><w:top w:w="110" w:type="dxa"/><w:left w:w="120" w:type="dxa"/><w:bottom w:w="110" w:type="dxa"/><w:right w:w="120" w:type="dxa"/></w:tcMar></w:tcPr><w:p><w:pPr><w:spacing w:after="0"/></w:pPr><w:r><w:rPr><w:sz w:val="19"/></w:rPr><w:t>Lambda + Connect API</w:t></w:r></w:p></w:tc>
        <w:tc><w:tcPr><w:tcW w:w="5336" w:type="dxa"/><w:tcMar><w:top w:w="110" w:type="dxa"/><w:left w:w="120" w:type="dxa"/><w:bottom w:w="110" w:type="dxa"/><w:right w:w="120" w:type="dxa"/></w:tcMar></w:tcPr><w:p><w:pPr><w:spacing w:after="0"/></w:pPr><w:r><w:rPr><w:sz w:val="19"/></w:rPr><w:t>Lists available routing profiles and processes routing-profile changes through the Amazon Connect API.</w:t></w:r></w:p></w:tc>
      </w:tr>
    </w:tbl>

    <w:p><w:pPr><w:spacing w:after="0"/></w:pPr></w:p>
    <w:p><w:pPr><w:pStyle w:val="SectionLabel"/></w:pPr><w:r><w:t>High-Level Scope</w:t></w:r></w:p>
    <w:p><w:pPr><w:pStyle w:val="ListBullet"/><w:spacing w:after="40"/><w:ind w:hanging="216"/></w:pPr><w:r><w:t>Configure the routing profile manager in the Amazon Connect Agent Workspace.</w:t></w:r></w:p>
    <w:p><w:pPr><w:pStyle w:val="ListBullet"/><w:spacing w:after="40"/><w:ind w:hanging="216"/></w:pPr><w:r><w:t>Deploy Lambda and its Function URL for routing-profile requests.</w:t></w:r></w:p>
    <w:p><w:pPr><w:pStyle w:val="ListBullet"/><w:spacing w:after="40"/><w:ind w:hanging="216"/></w:pPr><w:r><w:t>Configure the CloudFront/S3 frontend and Amazon Connect application integration.</w:t></w:r></w:p>
    <w:p><w:pPr><w:pStyle w:val="ListBullet"/><w:spacing w:after="40"/><w:ind w:hanging="216"/></w:pPr><w:r><w:t>Pilot test the application with one agent before wider rollout.</w:t></w:r></w:p>

    <w:p><w:pPr><w:pStyle w:val="SectionLabel"/></w:pPr><w:r><w:t>Client Questions and Decisions</w:t></w:r></w:p>
    <w:p><w:pPr><w:pStyle w:val="ListBullet"/><w:spacing w:after="40"/><w:ind w:hanging="216"/></w:pPr><w:r><w:t>Which agents, teams, or Amazon Connect security profiles should be able to use the application?</w:t></w:r></w:p>
    <w:p><w:pPr><w:pStyle w:val="ListBullet"/><w:spacing w:after="40"/><w:ind w:hanging="216"/></w:pPr><w:r><w:t>Should agents be allowed to change only their own routing profile, or should supervisors be able to change other agents?</w:t></w:r></w:p>
    <w:p><w:pPr><w:pStyle w:val="ListBullet"/><w:spacing w:after="40"/><w:ind w:hanging="216"/></w:pPr><w:r><w:t>Which current routing profiles should be eligible to use the change function?</w:t></w:r></w:p>
    <w:p><w:pPr><w:pStyle w:val="ListBullet"/><w:spacing w:after="40"/><w:ind w:hanging="216"/></w:pPr><w:r><w:t>Which destination routing profiles should agents be allowed to select?</w:t></w:r></w:p>
    <w:p><w:pPr><w:pStyle w:val="ListBullet"/><w:spacing w:after="40"/><w:ind w:hanging="216"/></w:pPr><w:r><w:t>Are specific source-to-destination routing-profile combinations required?</w:t></w:r></w:p>
    <w:p><w:pPr><w:pStyle w:val="ListBullet"/><w:spacing w:after="40"/><w:ind w:hanging="216"/></w:pPr><w:r><w:t>Should changes be allowed while an agent is handling a contact or completing after-contact work?</w:t></w:r></w:p>
    <w:p><w:pPr><w:pStyle w:val="ListBullet"/><w:spacing w:after="40"/><w:ind w:hanging="216"/></w:pPr><w:r><w:t>Is confirmation, supervisor approval, scheduled reversion, or an automatic return to the original profile required?</w:t></w:r></w:p>
    <w:p><w:pPr><w:pStyle w:val="ListBullet"/><w:spacing w:after="40"/><w:ind w:hanging="216"/></w:pPr><w:r><w:t>What authentication, network-access, and production security controls are required?</w:t></w:r></w:p>
    <w:p><w:pPr><w:pStyle w:val="ListBullet"/><w:spacing w:after="40"/><w:ind w:hanging="216"/></w:pPr><w:r><w:t>What audit history, log-retention period, monitoring, alerting, and operational support are required?</w:t></w:r></w:p>
    <w:p><w:pPr><w:pStyle w:val="ListBullet"/><w:spacing w:after="40"/><w:ind w:hanging="216"/></w:pPr><w:r><w:t>Which Amazon Connect instances and environments are included, and who will approve the pilot and production release?</w:t></w:r></w:p>
    <w:p><w:pPr><w:spacing w:after="100"/></w:pPr><w:r><w:rPr><w:i/><w:color w:val="595959"/><w:sz w:val="18"/></w:rPr><w:t>The answers may change the final architecture, implementation effort, and ongoing cost.</w:t></w:r></w:p>

    <w:p><w:pPr><w:pStyle w:val="SectionLabel"/></w:pPr><w:r><w:t>Estimated Effort and Costing</w:t></w:r></w:p>
    <w:tbl>
      <w:tblPr>
        <w:tblStyle w:val="TableGrid"/>
        <w:tblW w:w="0" w:type="auto"/>
        <w:jc w:val="center"/>
        <w:tblLayout w:type="fixed"/>
        <w:tblLook w:val="04A0" w:firstRow="1" w:lastRow="0" w:firstColumn="1" w:lastColumn="0" w:noHBand="0" w:noVBand="1"/>
      </w:tblPr>
      <w:tblGrid><w:gridCol w:w="3240"/><w:gridCol w:w="6696"/></w:tblGrid>
      <w:tr>
        <w:tc><w:tcPr><w:tcW w:w="3240" w:type="dxa"/><w:shd w:val="clear" w:fill="D9EAF7"/><w:tcMar><w:top w:w="135" w:type="dxa"/><w:left w:w="140" w:type="dxa"/><w:bottom w:w="135" w:type="dxa"/><w:right w:w="140" w:type="dxa"/></w:tcMar></w:tcPr><w:p><w:pPr><w:spacing w:after="0"/></w:pPr><w:r><w:rPr><w:b/><w:color w:val="1F4E79"/><w:sz w:val="19"/></w:rPr><w:t>Estimated implementation effort</w:t></w:r></w:p></w:tc>
        <w:tc><w:tcPr><w:tcW w:w="6696" w:type="dxa"/><w:tcMar><w:top w:w="135" w:type="dxa"/><w:left w:w="140" w:type="dxa"/><w:bottom w:w="135" w:type="dxa"/><w:right w:w="140" w:type="dxa"/></w:tcMar></w:tcPr><w:p><w:pPr><w:spacing w:after="0"/></w:pPr><w:r><w:rPr><w:sz w:val="19"/></w:rPr><w:t>8&#x2013;12 Developer Hours, plus 1&#x2013;2 Client AWS Admin Hours</w:t></w:r></w:p></w:tc>
      </w:tr>
      <w:tr>
        <w:tc><w:tcPr><w:tcW w:w="3240" w:type="dxa"/><w:shd w:val="clear" w:fill="D9EAF7"/><w:tcMar><w:top w:w="135" w:type="dxa"/><w:left w:w="140" w:type="dxa"/><w:bottom w:w="135" w:type="dxa"/><w:right w:w="140" w:type="dxa"/></w:tcMar></w:tcPr><w:p><w:pPr><w:spacing w:after="0"/></w:pPr><w:r><w:rPr><w:b/><w:color w:val="1F4E79"/><w:sz w:val="19"/></w:rPr><w:t>Estimated ongoing AWS cost</w:t></w:r></w:p></w:tc>
        <w:tc><w:tcPr><w:tcW w:w="6696" w:type="dxa"/><w:tcMar><w:top w:w="135" w:type="dxa"/><w:left w:w="140" w:type="dxa"/><w:bottom w:w="135" w:type="dxa"/><w:right w:w="140" w:type="dxa"/></w:tcMar></w:tcPr><w:p><w:pPr><w:spacing w:after="0"/></w:pPr><w:r><w:rPr><w:sz w:val="19"/></w:rPr><w:t>Approximately USD $0.10&#x2013;$0.50 per month for low-volume internal use of up to about 50,000 Lambda requests per month.</w:t></w:r></w:p></w:tc>
      </w:tr>
      <w:tr>
        <w:tc><w:tcPr><w:tcW w:w="3240" w:type="dxa"/><w:shd w:val="clear" w:fill="D9EAF7"/><w:tcMar><w:top w:w="135" w:type="dxa"/><w:left w:w="140" w:type="dxa"/><w:bottom w:w="135" w:type="dxa"/><w:right w:w="140" w:type="dxa"/></w:tcMar></w:tcPr><w:p><w:pPr><w:spacing w:after="0"/></w:pPr><w:r><w:rPr><w:b/><w:color w:val="1F4E79"/><w:sz w:val="19"/></w:rPr><w:t>Excluded</w:t></w:r></w:p></w:tc>
        <w:tc><w:tcPr><w:tcW w:w="6696" w:type="dxa"/><w:tcMar><w:top w:w="135" w:type="dxa"/><w:left w:w="140" w:type="dxa"/><w:bottom w:w="135" w:type="dxa"/><w:right w:w="140" w:type="dxa"/></w:tcMar></w:tcPr><w:p><w:pPr><w:spacing w:after="0"/></w:pPr><w:r><w:rPr><w:sz w:val="19"/></w:rPr><w:t>Existing CloudFront/S3 usage, standard Amazon Connect charges, taxes, and data transfer.</w:t></w:r></w:p></w:tc>
      </w:tr>
    </w:tbl>

    <w:p>
      <w:pPr><w:spacing w:before="100" w:after="0"/></w:pPr>
      <w:r>
        <w:rPr><w:i/><w:color w:val="595959"/><w:sz w:val="18"/></w:rPr>
        <w:t>Indicative estimate only. Actual cost depends on AWS Region, usage, log volume, and free-tier eligibility.</w:t>
      </w:r>
    </w:p>

    <w:sectPr>
      <w:footerReference w:type="default" r:id="rId8"/>
      <w:pgSz w:w="12240" w:h="15840"/>
      <w:pgMar w:top="936" w:right="1080" w:bottom="936" w:left="1080" w:header="720" w:footer="720" w:gutter="0"/>
      <w:cols w:space="720"/>
      <w:docGrid w:linePitch="360"/>
    </w:sectPr>
  </w:body>
</w:document>
'@

$modifiedUtc = [System.DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
$coreXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties
    xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:dcterms="http://purl.org/dc/terms/"
    xmlns:dcmitype="http://purl.org/dc/dcmitype/"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>Amazon Connect Routing Profile Manager - High-Level Write-Up and Costing</dc:title>
  <dc:subject>High-level architecture, implementation scope, and indicative costing</dc:subject>
  <dc:creator>OpenAI</dc:creator>
  <cp:keywords>Amazon Connect, routing profile, Lambda Function URL, Lambda, costing</cp:keywords>
  <dc:description>Simple high-level write-up and indicative costing for the routing profile manager.</dc:description>
  <cp:lastModifiedBy>OpenAI</cp:lastModifiedBy>
  <cp:revision>1</cp:revision>
  <dcterms:created xsi:type="dcterms:W3CDTF">$modifiedUtc</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">$modifiedUtc</dcterms:modified>
</cp:coreProperties>
"@

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

$oldDocument = $archive.GetEntry("word/document.xml")
if ($oldDocument) {
    $oldDocument.Delete()
}

$newDocument = $archive.CreateEntry(
    "word/document.xml",
    [System.IO.Compression.CompressionLevel]::Optimal
)
$writer = [System.IO.StreamWriter]::new(
    $newDocument.Open(),
    [System.Text.UTF8Encoding]::new($false)
)
$writer.Write($documentXml)
$writer.Dispose()

$oldCoreProperties = $archive.GetEntry("docProps/core.xml")
if ($oldCoreProperties) {
    $oldCoreProperties.Delete()
}

$newCoreProperties = $archive.CreateEntry(
    "docProps/core.xml",
    [System.IO.Compression.CompressionLevel]::Optimal
)
$coreWriter = [System.IO.StreamWriter]::new(
    $newCoreProperties.Open(),
    [System.Text.UTF8Encoding]::new($false)
)
$coreWriter.Write($coreXml)
$coreWriter.Dispose()

$archive.Dispose()
$packageStream.Dispose()

Write-Output $outputPath
