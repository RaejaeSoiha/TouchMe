# Start Nearby Connect mobile app in Chrome (API must be running via docker compose).
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $here
& "$here\flutter.ps1" pub get
& "$here\flutter.ps1" run -d chrome `
  --dart-define=API_BASE_URL=http://localhost:3000/api/v1 `
  --dart-define=SOCKET_BASE_URL=http://localhost:3000
