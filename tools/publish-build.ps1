$ErrorActionPreference = 'Stop'
$src = 'C:\Users\D\Documents\Collider\source\build\web'
$dst = 'C:\Users\D\Documents\Collider\app'
# Copy the build over the served tree WITHOUT /MIR. The build does not emit
# serve.ps1, vendor/, artifacts/ or tools/, and mirroring deleted them from the
# working tree once already. Copy only what the build actually produced.
& robocopy $src $dst /E /R:2 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
$code = $LASTEXITCODE
if ($code -ge 8) { throw "robocopy failed with $code" }
Write-Host "robocopy exit $code (0-7 are success)"
foreach ($f in @('main.dart.js', 'serve.ps1', 'flutter_bootstrap.js')) {
  $i = Get-Item "$dst\$f" -ErrorAction SilentlyContinue
  if ($i) { Write-Host ("{0,-22} {1,10}  {2}" -f $f, $i.Length, $i.LastWriteTime) }
  else { Write-Host "$f MISSING" }
}