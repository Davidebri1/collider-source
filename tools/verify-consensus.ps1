$ErrorActionPreference = 'Stop'
$base = 'http://127.0.0.1:28700'
$models = @('free/glm-5-3-flash','free/laguna-xs-2-1','free/nemotron-3-5-lightning')
$script:last = $null

# Write-Host, not Write-Output: inside a function, Write-Output would be
# captured into the return value instead of printing.
function Send-And-Wait($payload, $label, $timeoutSec) {
  $r = Invoke-RestMethod -Uri "$base/api/ask" -Method POST -Body ($payload | ConvertTo-Json -Depth 5) -ContentType 'application/json'
  $deadline = (Get-Date).AddSeconds($timeoutSec)
  do {
    Start-Sleep -Milliseconds 1500
    $j = Invoke-RestMethod -Uri "$base/api/job/$($r.id)" -TimeoutSec 10
  } while ($j.stage -ne 'done' -and (Get-Date) -lt $deadline)
  Write-Host "--- $label (stage=$($j.stage)) ---"
  if ($j.stage -ne 'done') { Write-Host "TIMED OUT"; return $null }
  $c = $j.consensus
  Write-Host "ratio=$($c.ratio)  score=$($c.score)  status=$($c.status)"
  Write-Host "excluded=$([string]::Join(',', @($c.excluded)))"
  Write-Host "groups=$(@($c.groups).Count):"
  foreach ($g in @($c.groups)) { Write-Host ("   [{0}] = {1}" -f $g.sentiment, ([string]::Join(', ', @($g.models)))) }
  Write-Host "chains=$(@($c.chains).Count):"
  foreach ($ch in @($c.chains)) { Write-Host ("   {0} = {1} chains, max {2}" -f $ch.model, $ch.chains, $ch.max) }
  Write-Host "consensus_chain=$($c.consensus_chain)"
  $names = $c.PSObject.Properties.Name
  Write-Host "dissent_present=$($names -contains 'dissent')  need_present=$($names -contains 'need')"
  return $c
}

Send-And-Wait @{ prompt='What is the one thing that makes a wallpaper feel alive rather than static?'; models=$models; mode='chat' } 'TEST 1: shared send, 3 models' 150 | Out-Null
Write-Host ""
$c2 = Send-And-Wait @{ prompt='Name one colour that reads as calm.'; models=$models; mode='chat'; excluded=@('free/laguna-xs-2-1') } 'TEST 2: R41, laguna excluded' 150
if ($c2) {
  Write-Host ""
  Write-Host "ASSERT denominator == 2 : $((($c2.ratio -split '/')[1]) -eq '2')"
  Write-Host "ASSERT excluded echoed  : $(([string]::Join(',', @($c2.excluded))) -eq 'free/laguna-xs-2-1')"
}