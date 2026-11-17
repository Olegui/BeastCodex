# Copies the addon into the game's AddOns folder.
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$addons = 'C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns'
if (-not (Test-Path $addons)) { throw "AddOns folder not found: $addons" }

$src = $repo; $dst = Join-Path $addons 'BeastCodex'
robocopy $src $dst /MIR /NJH /NJS /NDL /NP `
  /XD .git .cache .superpowers docs tools art-src media `
  /XF .gitignore .pkgmeta README.md CHANGELOG.md | Out-Host
# robocopy: 0-7 are success codes, 8+ are failures (e.g. folder not writable)
if ($LASTEXITCODE -ge 8) { throw "robocopy failed with code $LASTEXITCODE (is $addons writable?)" }
Write-Host "Installed to $dst"
exit 0
