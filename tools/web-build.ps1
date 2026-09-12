<#
.SYNOPSIS
    Packages LoveTactics as a .love and compiles it to a browser bundle with love.js.

.DESCRIPTION
    Two steps, either of which can be skipped:

      1. PACKAGE -- zips the runtime tree into build/LoveTactics.love. The include list below is
         the whole of what the game needs at run time; everything else in the repo (tests/,
         vendor/, docs/, art/, the Steam DLL) is dev-only weight that would land in the player's
         download for nothing. assets/ is BUILD OUTPUT -- run `. art-build` first or the bundle
         ships without art (models/sprite.lua tolerates a missing file silently, so this is easy
         to miss until it is already live).

      2. COMPILE -- runs love.js over that .love into build/web, then drops tools/web/index.html
         over the demo page love.js generates and tools/web/persist.js over the one line of glue
         that was supposed to be keeping the player's save (see Set-SavePersistence).

    Defaults to love.js's COMPATIBILITY build, and that is not a detail. The release build is
    multi-threaded: it needs SharedArrayBuffer, which a browser only hands to a page served with
    COOP/COEP headers, and GitHub Pages cannot set headers at all. The compat build is the same
    WebAssembly engine with the threads taken out -- and this game calls love.thread nowhere, so
    there is nothing here for them to have been doing. -Threaded is kept for a host that can
    send the headers.

    The output of step 2 is what tools/web-publish.ps1 pushes to the gh-pages branch.

.EXAMPLE
    powershell -File tools/web-build.ps1
    powershell -File tools/web-build.ps1 -SkipPackage -Serve   # recompile only, then serve it
#>
[CmdletBinding()]
param(
    # Reuse an existing build/LoveTactics.love instead of re-zipping ~40 MB.
    [switch]$SkipPackage,
    # Zip only; do not invoke love.js.
    [switch]$PackageOnly,
    # Build the threaded release engine. Only usable on a host that sends COOP/COEP -- see above.
    [switch]$Threaded,
    # Ship with the debug affordances off: the title screen's debug column, the battle's win
    # button, the right-click debug menu, the seed override. See Set-ReleaseDebugFlag.
    [switch]$Release,
    # Serve the finished bundle over HTTP. Opening index.html off disk does NOT work: the loader
    # fetches game.data with XHR and the browser refuses it on a file:// origin.
    [switch]$Serve,
    # Bytes of heap handed to the Emscripten runtime. love.js's own default (16 MB) is smaller
    # than this game's virtual filesystem, and it refuses outright below the packaged size.
    [int]$Memory = 536870912
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Root  = Split-Path -Parent $PSScriptRoot
$Build = Join-Path $Root 'build'
$Love  = Join-Path $Build 'LoveTactics.love'
$Web   = Join-Path $Build 'web'

# What the running game actually reads. An explicit allow-list rather than an exclude list, so a
# new dev-only folder cannot quietly gain 30 MB of download weight. tools/ is in because two
# debug surfaces require from it at file scope (states/debug_editor, states/menu).
$IncludeFiles = @('main.lua', 'conf.lua', 'scale.lua', 'input_mode.lua')
$IncludeDirs  = @('assets', 'data', 'models', 'shaders', 'states', 'tools', 'ui')

# ---------------------------------------------------------------------------
# Node
# ---------------------------------------------------------------------------

$script:NodeExe    = $null
$script:NpmCli     = $null
$script:GlobalRoot = $null
$script:LoveJs     = $null

# Prefer whatever is on PATH; fall back to the no-admin portable unpack in LOCALAPPDATA. Node's
# MSI needs elevation, so a machine may only ever have the second one.
#
# Everything below goes through node.exe and a resolved .js entry point, never through the `npx`
# or `npm` commands. On Windows those resolve to a .ps1 shim ahead of their .cmd, and the shim
# drops the arguments on the floor: `npx love.js <in> <out>` exits 0 having built nothing, which
# reads exactly like a successful build until the output directory turns out to be missing.
function Initialize-Node {
    # Bound first and tested for null: under Set-StrictMode, reaching for .Source on the $null
    # that Get-Command returns when node is absent raises instead of falling through.
    $onPath = Get-Command node.exe -ErrorAction SilentlyContinue
    $node = if ($onPath) { $onPath.Source } else { $null }
    if (-not $node) {
        $portable = Join-Path $env:LOCALAPPDATA 'node-portable\node.exe'
        if (Test-Path $portable) { $node = $portable }
    }
    if (-not $node) {
        throw "web-build: node is not on PATH and no portable copy sits in $env:LOCALAPPDATA\node-portable. Install Node LTS, or unzip the win-x64 build from nodejs.org there."
    }
    $script:NodeExe = $node

    $npmCli = Join-Path (Split-Path $node) 'node_modules/npm/bin/npm-cli.js'
    if (-not (Test-Path $npmCli)) { throw "web-build: this node install has no npm at $npmCli" }

    $script:NpmCli     = $npmCli
    $script:GlobalRoot = (& $node $npmCli root -g | Select-Object -Last 1).Trim()
    $script:LoveJs     = Resolve-GlobalScript 'love.js' 'love.js/index.js'
}

# The path to a script inside a globally installed package, installing the package if this
# machine has not got it yet.
function Resolve-GlobalScript([string]$package, [string]$relEntry) {
    $entry = Join-Path $script:GlobalRoot $relEntry
    if (-not (Test-Path $entry)) {
        Write-Host "$package is not installed -- fetching it"
        & $script:NodeExe $script:NpmCli install -g $package
        if (-not (Test-Path $entry)) { throw "web-build: installing $package did not produce $entry" }
    }
    return $entry
}

# ---------------------------------------------------------------------------
# 1. Package
# ---------------------------------------------------------------------------

# Write a zip entry from a string rather than copying a file, so a release build can differ from
# the working tree WITHOUT the working tree being edited. Flipping the flag on disk and reverting
# afterwards is the obvious alternative and a bad one: an interrupted build leaves the repository
# holding `Debug.enabled = false`, which is both a confusing local dev session and exactly the sort
# of line that gets committed by accident.
function Add-TextEntry($zip, [string]$name, [string]$text) {
    $entry = $zip.CreateEntry($name, 'Optimal')
    $stream = $entry.Open()
    try {
        $writer = New-Object System.IO.StreamWriter($stream, (New-Object System.Text.UTF8Encoding $false))
        $writer.Write($text)
        $writer.Flush()
        $writer.Dispose()
    } finally {
        $stream.Dispose()
    }
}

# models/debug.lua with its one build constant turned off. That module's own header names this as
# the way to make a release build, and every debug affordance in the game reads it -- the title
# screen's debug column, the battle's instant-win button, the right-click debug menu, the seed
# override -- so this single line is the whole of "not a dev build".
#
# Asserted rather than assumed: if the declaration is ever reworded, a silent no-op here would ship
# a debug build to the public web and look exactly like a release one.
function Set-ReleaseDebugFlag([string]$path) {
    $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
    $patched = $text -replace '(?m)^Debug\.enabled\s*=\s*true\s*$', 'Debug.enabled = false'
    if ($patched -eq $text) {
        throw "web-build: -Release could not find 'Debug.enabled = true' in models/debug.lua -- has it been reworded?"
    }
    return $patched
}

function New-LovePackage {
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    New-Item -ItemType Directory -Force $Build | Out-Null
    if (Test-Path $Love) { Remove-Item $Love }

    if (-not (Test-Path (Join-Path $Root 'assets'))) {
        Write-Warning 'assets/ is missing -- run the art build first, or the bundle ships with no art.'
    }

    # Entry by entry rather than CreateFromDirectory: staging a 40 MB copy into a temp tree only
    # to delete it again is the slowest part of an otherwise quick build.
    $zip = [System.IO.Compression.ZipFile]::Open($Love, 'Create')
    try {
        $count = 0
        foreach ($rel in $IncludeFiles) {
            $path = Join-Path $Root $rel
            if (-not (Test-Path $path)) { throw "web-build: $rel is missing from the project root" }
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $path, $rel, 'Optimal') | Out-Null
            $count++
        }
        foreach ($dir in $IncludeDirs) {
            $base = Join-Path $Root $dir
            if (-not (Test-Path $base)) { continue }
            foreach ($file in Get-ChildItem -Path $base -Recurse -File) {
                # Zip entry names are '/'-separated by spec, and LOVE's mount does not forgive a backslash.
                $rel = $file.FullName.Substring($Root.Length + 1).Replace('\', '/')
                if ($Release -and $rel -eq 'models/debug.lua') {
                    Add-TextEntry $zip $rel (Set-ReleaseDebugFlag $file.FullName)
                } else {
                    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, $rel, 'Optimal') | Out-Null
                }
                $count++
            }
        }
    } finally {
        $zip.Dispose()
    }

    $flavour = if ($Release) { 'release, debug affordances off' } else { 'DEV BUILD, debug affordances on' }
    Write-Host ("packaged {0} files -> build/LoveTactics.love ({1:N1} MB, {2})" -f $count, ((Get-Item $Love).Length / 1MB), $flavour)
}

# ---------------------------------------------------------------------------
# 2. Compile
# ---------------------------------------------------------------------------

function Invoke-LoveJs {
    if (Test-Path $Web) { Remove-Item -Recurse -Force $Web }

    # The DISPLAY name, which is not the repository's. The game was renamed to Project Tactics;
    # "LoveTactics" survives only as identifiers -- t.identity, the repo and wiki URLs, and this
    # build's artifact filenames -- none of which a player ever sees.
    $cli = @($Love, $Web, '--title', 'Project Tactics', '--memory', "$Memory")
    if (-not $Threaded) { $cli += '--compatibility' }

    & $script:NodeExe $script:LoveJs @cli
    if ($LASTEXITCODE -ne 0) { throw "web-build: love.js exited $LASTEXITCODE" }

    # love.js has been seen to exit 0 having written nothing at all (a cold npx fetch appears to
    # end the process before the build promise settles). Trust the artifacts, not the exit code:
    # the next step would otherwise fail on a missing directory and blame itself.
    foreach ($artifact in @('game.data', 'game.js', 'love.js', 'love.wasm')) {
        if (-not (Test-Path (Join-Path $Web $artifact))) {
            throw "web-build: love.js reported success but produced no $artifact -- run it again"
        }
    }

    # Replace love.js's one-line save flush with tools/web/persist.js. Ahead of the cache stamp,
    # which hashes love.js AFTER every edit to it -- a patch applied afterwards would ship under
    # the previous build's ?v= and be served from cache.
    Set-SavePersistence

    # Stamp each fetched artifact's URL with a hash of its own contents. Without this the browser
    # keeps serving the PREVIOUS deploy's 28 MB game.data -- Pages hands it out as max-age=600
    # under a name that never changes -- so a republished bundle goes on running the old Lua, and
    # a crash that was fixed goes on crashing.
    $gameJs, $loveJs = Set-CacheStamp

    Set-ShippingPage $gameJs $loveJs

    $mb = (Get-ChildItem $Web -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
    $engine = if ($Threaded) { 'threaded' } else { 'compat' }
    Write-Host ("compiled -> build/web ({0:N1} MB total, {1})" -f $mb, $engine)
}

# The save directory is an IDBFS mount, and love.js flushes it to IndexedDB from a beforeunload
# handler alone -- which never works, because FS.syncfs is asynchronous and the document is gone
# before the transaction commits. Every campaign was therefore discarded with the tab. The
# replacement flushes on the WRITE instead; tools/web/persist.js carries the whole explanation.
#
# It has to go here, into the generated glue, because `FS` lives inside love.js's module closure
# and this build exports no handle on it: a <script> in index.html cannot reach the filesystem at
# all. Asserted rather than assumed, exactly as Set-CacheStamp is -- if an upgrade rewords the
# line, a silent no-op here would ship a build that quietly loses saves again.
function Set-SavePersistence {
    $path = Join-Path $Web 'love.js'
    $find = 'window.addEventListener("beforeunload",function(event){FS.syncfs(false,function(err){if(err){Module["printErr"](err)}})})'

    $text = [System.IO.File]::ReadAllText($path)
    if (-not $text.Contains($find)) {
        throw "web-build: love.js no longer contains its beforeunload save flush -- love.js has changed its glue, and saves would ship unpersisted (see tools/web/persist.js)"
    }

    $persist = Join-Path $PSScriptRoot 'web/persist.js'
    if (-not (Test-Path $persist)) { throw 'web-build: tools/web/persist.js is missing' }

    $utf8 = New-Object System.Text.UTF8Encoding $false
    $patch = "`n/* tools/web/persist.js */`n" + [System.IO.File]::ReadAllText($persist, [System.Text.Encoding]::UTF8)
    [System.IO.File]::WriteAllText($path, $text.Replace($find, $patch), $utf8)
}

# Content-hashed URLs for the four artifacts a player's browser fetches. game.js asks for
# game.data by a fixed name, love.js asks for love.wasm by a fixed name, and index.html asks for
# both scripts. GitHub Pages serves every one of them with max-age=600 and offers no way to say
# otherwise, so a returning player runs whatever mixture of old and new files their cache happens
# to hold. Each URL carries ?v=<hash of that file>: a file that did not change keeps its URL and
# its cached copy, one that did is fetched fresh. Per-file hashes rather than a single build
# stamp for exactly that reason -- love.wasm is 4.7 MB and changes only when love.js is upgraded.
# Returns the two script stamps, which the page hangs its <script> tags off.
function Set-CacheStamp {
    function Get-Stamp([string]$file) {
        (Get-FileHash -Algorithm SHA256 -Path (Join-Path $Web $file)).Hash.Substring(0, 12).ToLower()
    }

    # These two patterns are love.js's generated glue, not ours. If an upgrade rewords either one,
    # stop: a silently un-stamped URL is the whole bug this function exists to prevent.
    $glue = @(
        @{ file = 'game.js'; find = "REMOTE_PACKAGE_BASE = 'game.data'"; asset = 'game.data' },
        @{ file = 'love.js'; find = 'wasmBinaryFile="love.wasm"';        asset = 'love.wasm' }
    )
    $utf8 = New-Object System.Text.UTF8Encoding $false
    foreach ($g in $glue) {
        $path = Join-Path $Web $g.file
        $text = [System.IO.File]::ReadAllText($path)
        if (-not $text.Contains($g.find)) {
            throw "web-build: $($g.file) no longer contains [$($g.find)] -- love.js has changed its glue, and $($g.asset) would ship on an un-stamped URL that browsers keep serving stale"
        }
        $stamped = $g.find.Replace($g.asset, "$($g.asset)?v=$(Get-Stamp $g.asset)")
        [System.IO.File]::WriteAllText($path, $text.Replace($g.find, $stamped), $utf8)
    }

    # Hashed after patching, so each script's own stamp covers the URL it was just given.
    return (Get-Stamp 'game.js'), (Get-Stamp 'love.js')
}

# love.js writes a demo page: an 800x600 canvas on a sky-blue ground, no download progress, and
# the engine started before the player has clicked anything. tools/web/index.html replaces it.
# The emscripten glue (love.js, love.wasm, game.js, game.data) is left exactly as generated,
# apart from the cache stamps above.
function Set-ShippingPage([string]$GameJs, [string]$LoveJs) {
    $template = Join-Path $PSScriptRoot 'web/index.html'
    if (-not (Test-Path $template)) { throw 'web-build: tools/web/index.html is missing' }

    $html = (Get-Content $template -Raw).Replace('__TITLE__', 'Project Tactics').Replace('__MEMORY__', "$Memory").Replace('__GAME_JS__', $GameJs).Replace('__LOVE_JS__', $LoveJs)
    # UTF-8 with no BOM: a BOM ahead of the doctype drops the browser into quirks mode.
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText((Join-Path $Web 'index.html'), $html, $utf8)

    # GitHub Pages runs Jekyll by default, which drops any path beginning with an underscore and
    # would rather template our HTML than serve it. .nojekyll turns the whole thing off.
    [System.IO.File]::WriteAllText((Join-Path $Web '.nojekyll'), '')
}

# ---------------------------------------------------------------------------

if (-not $PackageOnly) { Initialize-Node }
if (-not $SkipPackage) { New-LovePackage }
if (-not $PackageOnly) { Invoke-LoveJs }

if ($Serve) {
    if (-not $script:NodeExe) { Initialize-Node }
    $server = Resolve-GlobalScript 'http-server' 'http-server/bin/http-server'
    Write-Host 'serving build/web on http://localhost:8080/ -- Ctrl+C to stop'
    & $script:NodeExe $server $Web -p 8080 -c-1
}
