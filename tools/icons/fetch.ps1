# One-time setup for the icon pipeline. Run from the project root:
#
#     powershell -ExecutionPolicy Bypass -File tools\icons\fetch.ps1
#
# Puts two third-party things under vendor/ (gitignored, reproducible on demand):
#
#   vendor/game-icons/   the game-icons.net SVG sources, cloned from GitHub. ~4200 icons laid out
#                        as <author>/<slug>.svg. CC BY 3.0 -- see the attribution note below.
#   vendor/bin/resvg.exe the rasterizer. game-icons' own rasterize-svgs.sh uses resvg, so this
#                        matches how the upstream project renders its own PNGs.
#
# Neither is committed. The PNGs the pipeline renders FROM them are what lands in assets/.
# See docs/art-assets.md, then run `. icon-map` and `. icon-build`.
#
# ATTRIBUTION: game-icons.net is CC BY 3.0 and requires crediting the authors. `. icon-build`
# generates docs/credits-icons.md listing exactly which artists' icons shipped -- do not drop it.

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$vendor = Join-Path $root 'vendor'
$icons = Join-Path $vendor 'game-icons'
$bin = Join-Path $vendor 'bin'

New-Item -ItemType Directory -Force -Path $vendor | Out-Null
New-Item -ItemType Directory -Force -Path $bin | Out-Null

# --- the icon sources -------------------------------------------------------
if (Test-Path (Join-Path $icons '.git')) {
    Write-Host "game-icons: already cloned, pulling"
    git -C $icons pull --ff-only
} else {
    Write-Host "game-icons: cloning (shallow)"
    git clone --depth 1 https://github.com/game-icons/icons.git $icons
}

$svgCount = (Get-ChildItem -Path $icons -Filter *.svg -Recurse).Count
Write-Host "game-icons: $svgCount icons available"

# --- the rasterizer ---------------------------------------------------------
# Pinned rather than tracking `latest`, so a re-render years from now produces the same pixels.
$resvgVersion = 'v0.47.0'
$resvgExe = Join-Path $bin 'resvg.exe'

if (Test-Path $resvgExe) {
    Write-Host "resvg: already present"
} else {
    $url = "https://github.com/linebender/resvg/releases/download/$resvgVersion/resvg-win64.zip"
    $zip = Join-Path $env:TEMP "resvg-$resvgVersion.zip"
    Write-Host "resvg: downloading $resvgVersion"
    Invoke-WebRequest -Uri $url -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $bin -Force
    Remove-Item $zip -Force
}

if (-not (Test-Path $resvgExe)) {
    throw "resvg.exe did not land in $bin -- check the release asset layout for $resvgVersion"
}

& $resvgExe --version
Write-Host ""
Write-Host "ready. next:  & `"E:\LOVE\lovec.exe`" . icon-map"
