# Run native Flutter tests using an ASCII-only temporary directory on Windows.
$ErrorActionPreference = 'Stop'
$previousTemp = $env:TEMP
$previousTmp = $env:TMP
$testTemp = Join-Path (Split-Path $PSScriptRoot -Parent) '.tmp'
New-Item -ItemType Directory -Path $testTemp -Force | Out-Null
try {
    $env:TEMP = $testTemp
    $env:TMP = $testTemp
    flutter test --concurrency=1 @args
    $testExitCode = $LASTEXITCODE
} finally {
    $env:TEMP = $previousTemp
    $env:TMP = $previousTmp
}
exit $testExitCode
