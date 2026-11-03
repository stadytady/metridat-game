<#
Runs the same import, unit tests and walkthrough checks as tools/test.sh on Windows.
Usage: .\tools\test.ps1
##>
[CmdletBinding()]
param()

# Godot writes harmless shutdown warnings to stderr; exit codes below are decisive.
$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
$godot = Join-Path $PSScriptRoot "bin\godot\Godot_v4.5.1-stable_win64.exe"
if (-not (Test-Path -LiteralPath $godot)) {
	$godot = "godot"
}

Push-Location $root
try {
	# Import failures are non-fatal here, matching the POSIX test script.
	& cmd.exe /d /c "`"$godot`" --headless --path . --import" | Write-Output
	$unit = & cmd.exe /d /c "`"$godot`" --headless --path . -s res://tests/run_tests.gd" 2>&1
	$unit | Write-Output
	if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
	$walkthrough = & cmd.exe /d /c "`"$godot`" --headless --path . --fixed-fps 60 -- --walkthrough" 2>&1
	$walkthrough | Write-Output
	$log = $walkthrough -join "`n"
	if ($LASTEXITCODE -ne 0 -or $log -notmatch "WALKTHROUGH PASS" -or $log -match "SCRIPT ERROR|Parse Error") {
		exit 1
	}
}
finally {
	Pop-Location
}
