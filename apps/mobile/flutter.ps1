# Nearby Connect — run Flutter without relying on global PATH.
$flutter = 'C:\flutter\bin\flutter.bat'
if (-not (Test-Path $flutter)) {
  Write-Error "Flutter not found at $flutter. Install from https://docs.flutter.dev/get-started/install/windows"
  exit 1
}
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-22'
$env:ANDROID_HOME = 'C:\Users\Ourmon\AppData\Local\Temp\android-sdk'
$env:Path = 'C:\flutter\bin;' + $env:Path
& $flutter @args
