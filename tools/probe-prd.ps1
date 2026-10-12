$ErrorActionPreference = 'Continue'
$f = 'C:\Users\D\Documents\Collider-PRD.xlsx'
$fi = Get-Item -LiteralPath $f
Write-Output "SIZE $($fi.Length)  MTIME $($fi.LastWriteTime)"
# xlsx is a zip; read sharedStrings.xml + sheet1 without external libs
Add-Type -AssemblyName System.IO.Compression.FileSystem
try {
  $zip = [System.IO.Compression.ZipFile]::OpenRead($f)
  Write-Output "ENTRIES:"
  $zip.Entries | ForEach-Object { Write-Output "  $($_.FullName)  $($_.Length)" }
  $zip.Dispose()
} catch {
  Write-Output "ZIP ERR: $($_.Exception.Message)"
}