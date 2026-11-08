# Saves the PGO training data from the RUNNING training emulator (FEFW-PGO-Training\eden.exe).
# Run it while you're still in the game, before closing the emulator:
#   .\Save-PGO.ps1
# Each run adds another eden!N.pgc to pgo-fefw\, so you can run it more than once.
$ErrorActionPreference = 'Stop'
$pgoDir = Join-Path $PSScriptRoot 'pgo-fefw'
if (-not (Test-Path (Join-Path $pgoDir 'eden.pgd'))) { throw 'No pgo-fefw\eden.pgd: build the training copy first (-Pgo Train).' }
if (-not (Get-Process eden -ErrorAction SilentlyContinue)) { throw 'eden.exe is not running. Start FEFW-PGO-Training\eden.exe, play, and run this before closing it.' }
$sweep = Get-ChildItem "${env:ProgramFiles}\Microsoft Visual Studio\*\*\VC\Tools\MSVC\*\bin\Hostx64\x64\pgosweep.exe" -ErrorAction SilentlyContinue |
         Sort-Object FullName -Descending | Select-Object -First 1
if (-not $sweep) { throw 'pgosweep.exe not found in your Visual Studio install.' }
$n = 1; while (Test-Path (Join-Path $pgoDir "eden!$n.pgc")) { $n++ }
$out = Join-Path $pgoDir "eden!$n.pgc"
& $sweep.FullName eden.exe $out
if ($LASTEXITCODE -or -not (Test-Path $out)) { throw "pgosweep failed ($LASTEXITCODE)." }
Write-Host ("Saved {0} ({1:N1} MB). You can close the emulator now, then run:" -f (Split-Path $out -Leaf), ((Get-Item $out).Length / 1MB)) -ForegroundColor Green
Write-Host '  .\Build-Local-MSVC.ps1 -Version 1.12 -Portable -Pgo Use' -ForegroundColor Yellow
