# Builds the release zip, dist/BeastCodex-<version>.zip, holding the BeastCodex
# folder with what the game needs (the same set install.ps1 copies).
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$version = (Select-String -Path (Join-Path $repo 'BeastCodex.toc') -Pattern '^## Version: (.+)$').Matches[0].Groups[1].Value.Trim()
$stage = Join-Path $repo '.cache\stage'
$folder = Join-Path $stage 'BeastCodex'
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force $folder | Out-Null
robocopy $repo $folder /MIR /NJH /NJS /NDL /NP /NFL `
  /XD .git .cache .superpowers docs tools art-src media dist `
  /XF .gitignore .pkgmeta CHANGELOG.md | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed with code $LASTEXITCODE" }
$dist = Join-Path $repo 'dist'
New-Item -ItemType Directory -Force $dist | Out-Null
$zip = Join-Path $dist "BeastCodex-$version.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path $folder -DestinationPath $zip
Write-Output $zip
exit 0
