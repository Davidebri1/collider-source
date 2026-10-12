$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$f = 'C:\Users\D\Documents\Collider-PRD.xlsx'
$out = 'C:\Users\D\Documents\Collider\docs\PRD-XLSX-EXTRACT.txt'
$zip = [System.IO.Compression.ZipFile]::OpenRead($f)
$sb = New-Object System.Text.StringBuilder
$names = $zip.Entries | Where-Object { $_.FullName -match '^xl/worksheets/sheet\d+\.xml$' } | Sort-Object FullName
foreach ($e in $names) {
  $sr = New-Object System.IO.StreamReader($e.Open())
  $xml = [xml]$sr.ReadToEnd()
  $sr.Close()
  [void]$sb.AppendLine("===== $($e.FullName) =====")
  $nsm = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
  $nsm.AddNamespace('d','http://schemas.openxmlformats.org/spreadsheetml/2006/main')
  foreach ($row in $xml.SelectNodes('//d:sheetData/d:row',$nsm)) {
    $cells = @()
    foreach ($c in $row.SelectNodes('d:c',$nsm)) {
      $v = $null
      if ($c.t -eq 'inlineStr') { $v = ($c.SelectNodes('.//d:t',$nsm) | ForEach-Object { $_.InnerText }) -join '' }
      else { $vn = $c.SelectSingleNode('d:v',$nsm); if ($vn) { $v = $vn.InnerText } }
      if ($v -and $v.Trim()) { $cells += $v.Trim() }
    }
    if ($cells.Count -gt 0) { [void]$sb.AppendLine(($cells -join ' | ')) }
  }
  [void]$sb.AppendLine('')
}
$zip.Dispose()
[System.IO.File]::WriteAllText($out, $sb.ToString(), [System.Text.UTF8Encoding]::new($false))
Write-Output "WROTE $((Get-Item $out).Length) bytes -> $out"