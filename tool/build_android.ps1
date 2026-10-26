# Use an ASCII-only Pub cache without changing Windows Developer Mode.
$ErrorActionPreference = 'Continue'
$previousPubCache = $env:PUB_CACHE
try {
    $env:PUB_CACHE = Join-Path (Split-Path $PSScriptRoot -Parent) '.pub-cache'
    $restoreOutput = & flutter pub get 2>&1
    $restoreExitCode = $LASTEXITCODE
    $restoreOutput | ForEach-Object { Write-Output $_ }
    $restoreText = $restoreOutput -join "`n"
    if ($restoreExitCode -ne 0 -and -not ($restoreText.Contains('Got dependencies!') -and $restoreText.Contains('symlink support'))) { exit $restoreExitCode }
    # Desktop symlink setup is unrelated to an Android-only build.
    flutter build apk --debug --no-pub @args
    $buildExitCode = $LASTEXITCODE
} finally {
    $env:PUB_CACHE = $previousPubCache
}
exit $buildExitCode
