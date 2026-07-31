$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Python = Get-Command python -ErrorAction SilentlyContinue
if ($Python) {
    & $Python.Source (Join-Path $PSScriptRoot "validate_release.py")
} else {
    $Py = Get-Command py -ErrorAction Stop
    & $Py.Source (Join-Path $PSScriptRoot "validate_release.py")
}
exit $LASTEXITCODE
