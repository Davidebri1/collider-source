$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$mime = @{'.html'='text/html';'.js'='application/javascript';'.mjs'='application/javascript';'.wasm'='application/wasm';'.json'='application/json';'.png'='image/png';'.jpg'='image/jpeg';'.jpeg'='image/jpeg';'.webp'='image/webp';'.gif'='image/gif';'.svg'='image/svg+xml';'.css'='text/css';'.ttf'='font/ttf';'.otf'='font/otf';'.woff'='font/woff';'.woff2'='font/woff2';'.mp4'='video/mp4';'.webm'='video/webm';'.mp3'='audio/mpeg';'.wav'='audio/wav';'.ico'='image/x-icon'}
$port = 28610; $l = $null
while ($port -lt 28700) { try { $l = New-Object System.Net.HttpListener; $l.Prefixes.Add("http://localhost:$port/"); $l.Start(); break } catch { $port++ } }
Start-Process "http://localhost:$port/"
while ($l.IsListening) {
  $c = $l.GetContext(); $p = [Uri]::UnescapeDataString($c.Request.Url.AbsolutePath.TrimStart('/'))
  if ($p -eq '') { $p = 'index.html' }
  $f = Join-Path $root $p
  if (-not (Test-Path $f -PathType Leaf)) { $f = Join-Path $root 'index.html' }
  $t = $mime[[IO.Path]::GetExtension($f).ToLower()]; if (-not $t) { $t = 'application/octet-stream' }
  try { $b = [IO.File]::ReadAllBytes($f); $c.Response.ContentType = $t; $c.Response.ContentLength64 = $b.Length; $c.Response.OutputStream.Write($b, 0, $b.Length) } catch {} finally { $c.Response.Close() }
}
