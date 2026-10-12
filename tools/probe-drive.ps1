$ErrorActionPreference = 'Continue'
$tests = @(
  'P:\My Drive\Google AI Studio\Extended Spec.txt',
  'P:\My Drive\collider_flutter 091826 GROK\docs\COLLIDER_SPEC.md',
  'P:\My Drive\collider_flutter 091826 GROK\docs\CONSENSUS_MAP.md'
)
foreach ($t in $tests) {
  try {
    $c = [System.IO.File]::ReadAllText($t)
    Write-Output "READ-OK  $($c.Length) chars :: $t"
  } catch {
    Write-Output "FAIL     $($_.Exception.Message) :: $t"
  }
}
Write-Output "--- attributes of consensus agent ---"
Get-Item -LiteralPath 'P:\My Drive\AI Agents & Prompts\Consensus Agent.agent.md' -Force |
  Select-Object FullName, Length, Attributes, LastWriteTime | Format-List