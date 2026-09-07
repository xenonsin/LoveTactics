<#
.SYNOPSIS
    Publishes build/web to the gh-pages branch, which GitHub Pages serves at
    https://xenonsin.github.io/LoveTactics/

.DESCRIPTION
    The branch is rewritten, not appended to: every publish replaces gh-pages with a single
    ORPHAN commit and force-pushes it. That is deliberate. game.data is ~27 MB and changes with
    every content edit, so an accumulating branch would add 27 MB of permanently reachable blob
    to the repository each time it was published. One commit means one copy, and the branch
    carries no history worth keeping -- main has all of it.

    Nothing here touches the main working tree. The commit is assembled in a throwaway git
    worktree under the system temp directory and the worktree is removed afterwards, so an
    interrupted publish cannot leave the checkout on the wrong branch.

.EXAMPLE
    powershell -File tools/web-publish.ps1 -WhatIf   # stage and report, push nothing
    powershell -File tools/web-publish.ps1
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$Branch = 'gh-pages',
    [string]$Remote = 'origin'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Root = Split-Path -Parent $PSScriptRoot
$Web  = Join-Path $Root 'build/web'

# Deliberately NOT `2>&1`. Windows PowerShell wraps every stderr line from a native command in an
# ErrorRecord, and git writes ordinary progress there -- so under ErrorActionPreference 'Stop' the
# publish died on "Updating files: 55%" from a `git worktree add` that was working perfectly well.
# The exit code is the only honest signal; stderr is left to flow to the console where it belongs.
function Invoke-Git {
    param([string[]]$Arguments, [string]$In = $Root)
    $output = & git -C $In @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "web-publish: git $($Arguments -join ' ') failed (exit $LASTEXITCODE)"
    }
    return $output
}

# ---------------------------------------------------------------------------
# What we are about to publish
# ---------------------------------------------------------------------------

if (-not (Test-Path (Join-Path $Web 'game.data'))) {
    throw 'web-publish: build/web holds no game.data -- run tools/web-build.ps1 first'
}
if (-not (Test-Path (Join-Path $Web '.nojekyll'))) {
    # Without it Pages runs the output through Jekyll, which drops underscore-prefixed paths.
    throw 'web-publish: build/web has no .nojekyll -- rebuild with tools/web-build.ps1'
}

$sourceSha = (Invoke-Git @('rev-parse', '--short', 'HEAD')).Trim()
$dirty     = (Invoke-Git @('status', '--porcelain')) -ne $null
$mb        = (Get-ChildItem $Web -Recurse -File -Force | Measure-Object -Property Length -Sum).Sum / 1MB

Write-Host ("publishing build/web ({0:N1} MB) as {1}, built from {2}{3}" -f $mb, $Branch, $sourceSha, $(if ($dirty) { ' plus uncommitted changes' } else { '' }))

if (-not $PSCmdlet.ShouldProcess("$Remote/$Branch", 'force-push the web build')) { return }

# ---------------------------------------------------------------------------
# Assemble the commit somewhere harmless
# ---------------------------------------------------------------------------

$stage = Join-Path ([System.IO.Path]::GetTempPath()) ("lovetactics-pages-" + [guid]::NewGuid().ToString('N').Substring(0, 8))

try {
    Invoke-Git @('worktree', 'add', '--detach', $stage) | Out-Null

    # An orphan checkout keeps main's files in the index, so clear it before copying ours in --
    # otherwise the published branch carries the whole source tree alongside the bundle.
    Invoke-Git @('checkout', '--orphan', $Branch) -In $stage | Out-Null
    Invoke-Git @('rm', '-rf', '--quiet', '.') -In $stage | Out-Null

    Copy-Item -Path (Join-Path $Web '*') -Destination $stage -Recurse -Force
    # -Force on the glob above still skips dotfiles in PowerShell 5.1; .nojekyll is the whole
    # reason this branch renders at all, so it is copied by name.
    Copy-Item -Path (Join-Path $Web '.nojekyll') -Destination $stage -Force

    Invoke-Git @('add', '-A') -In $stage | Out-Null
    Invoke-Git @('commit', '-m', "Publish the web build from $sourceSha") -In $stage | Out-Null
    Invoke-Git @('push', '--force', $Remote, "${Branch}:${Branch}") -In $stage | Out-Null

    Write-Host "pushed $Remote/$Branch -- https://xenonsin.github.io/LoveTactics/"
} finally {
    # --force because the orphan checkout leaves the worktree on a branch git would rather keep.
    & git -C $Root worktree remove --force $stage 2>&1 | Out-Null
    if (Test-Path $stage) { Remove-Item -Recurse -Force $stage -ErrorAction SilentlyContinue }
}
