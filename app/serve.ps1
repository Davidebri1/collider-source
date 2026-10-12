# Starts the Collider server: the built web app plus the /api it calls.
# Node is the whole runtime; no install step.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$port = $env:PORT; if (-not $port) { $port = 28700 }

# if the port is already held by a healthy Collider server, just open it
$existing = $null
try { $existing = Invoke-WebRequest "http://localhost:$port/api/health" -UseBasicParsing -TimeoutSec 2 } catch {}

if ($existing -and $existing.StatusCode -eq 200) {
    Start-Process "http://localhost:$port/"
    Write-Host "Collider already running on http://localhost:$port/"
    return
}

$env:PORT = $port
$env:COLLIDER_WEB_ROOT = Join-Path $root 'app'
Write-Host "Collider starting on http://localhost:$port/"
Start-Process "http://localhost:$port/"
node (Join-Path $root '..\server\collider-server.mjs')