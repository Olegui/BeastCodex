# Copies the addon (or the throwaway probe with -Probe) into the game's AddOns folder.
param([switch]$Probe)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$addons = 'C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns'
if (-not (Test-Path $addons)) { throw "AddOns folder not found: $addons" }

if ($Probe) {
  $src = Join-Path $repo 'Probe'; $dst = Join-Path $addons 'BeastCodexProbe'
  robocopy $src $dst /MIR /NJH /NJS /NDL /NP | Out-Host
} else {
  $src = $repo; $dst = Join-Path $addons 'BeastCodex'
  robocopy $src $dst /MIR /NJH /NJS /NDL /NP `
    /XD .git .cache .superpowers docs tools Probe art-src media `
    /XF .gitignore .pkgmeta | Out-Host
}
# robocopy: 0-7 are success codes, 8+ are failures (e.g. folder not writable)
if ($LASTEXITCODE -ge 8) { throw "robocopy failed with code $LASTEXITCODE (is $addons writable?)" }
Write-Host "Installed to $dst"
exit 0
