# llmman installer (Windows) — installs or upgrades llmman with Scoop when
# scoop is present; otherwise downloads the llmman.exe binary matching this
# host's CPU architecture from GitHub Releases to
# %LOCALAPPDATA%\Microsoft\WindowsApps, which is already on PATH for every
# user account by default on Windows 10/11. For Linux/macOS, use
# install.sh instead.
#
#   irm https://raw.githubusercontent.com/llmmanorg/llmman/main/install.ps1 | iex
#
# GPU/backend detection happens at runtime inside the llmman binary
# itself, the first time `llmman serve` needs a `llama-server` (see
# src/hostgpu.rs and src/llama_release.rs) — this script just gets
# llmman.exe onto PATH.
#
# Supported today (matches .github/workflows/ci.yml's build matrix):
#   Windows x86_64, aarch64
#
# Env overrides:
#   LLMMAN_VERSION   pin an exact release tag (e.g. "v0.2.0"); default: latest
#   LLMMAN_REPO      "owner/repo" to fetch from; default: llmmanorg/llmman
#   LLMMAN_BASE_URL  release base URL to fetch from, in place of GitHub's own
#                    "https://github.com/$Repo/releases"; exists so CI
#                    (.github/workflows/ci.yml's e2e job) can point this
#                    script at a throwaway local HTTP server serving that
#                    job's own just-built binary instead — a real GitHub
#                    release for a commit/PR still under test wouldn't exist
#                    yet — while every other part of the install (arch
#                    detection, the download itself, the --version smoke
#                    check, the final install-directory copy) still runs
#                    completely unmodified against a real HTTP round trip.
#   SKIP_INSTALL     download and verify only, don't install

function Die {
    param([string[]]$Messages)
    $Messages | ForEach-Object { [Console]::Error.WriteLine($_) }
    exit 111
}

function UseScoop {
    param([string]$Repo)
    if (!(Get-Command scoop -ErrorAction SilentlyContinue)) { return $false }
    if ($env:LLMMAN_VERSION -or $env:LLMMAN_BASE_URL -or $env:SKIP_INSTALL) { return $false }
    if ($Repo -ne "llmmanorg/llmman") { return $false }
    return !(Test-Path (Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\llmman.exe"))
}

function ScoopApp {
    $Buckets = @(scoop bucket list | Where-Object { "$($_.Source)" -match 'github\.com/llmmanorg/scoop-bucket' } | ForEach-Object { $_.Name })
    scoop list | Where-Object { $_.Name -eq "llmman" -and $Buckets -contains $_.Source } | Select-Object -First 1
}

function Main {
    $Repo = $env:LLMMAN_REPO
    if (!$Repo) { $Repo = "llmmanorg/llmman" }

    if (UseScoop $Repo) {
        $App = ScoopApp
        if ($App) {
            $Scope = @()
            if ("$($App.Info)" -match 'Global') { $Scope = @("--global") }
            $Before = scoop list llmman *>&1 | Out-String
            scoop update llmman @Scope
            if ($LASTEXITCODE) { Die "scoop update failed" }
            # scoop update skips an app whose process is running
            if ($Before -eq (scoop list llmman *>&1 | Out-String)) {
                "llmman is unchanged; if it is running, stop it and run: scoop update llmman"
            }
        } else {
            # an already-added bucket makes this fail harmlessly
            scoop bucket add llmman https://github.com/llmmanorg/scoop-bucket
            scoop install llmman/llmman
            if ($LASTEXITCODE) { Die "scoop install failed" }
            if (!(ScoopApp)) { Die "llmman/llmman is not installed; is another llmman installed?" }
        }
        "Installation completed successfully"
        return
    }

    switch ($env:PROCESSOR_ARCHITECTURE) {
        "ARM64" { $Target = "aarch64-pc-windows-msvc" }
        "AMD64" { $Target = "x86_64-pc-windows-msvc" }
        default { Die "Arch not supported: $env:PROCESSOR_ARCHITECTURE" }
    }

    $Asset = "llmman-$Target.exe"
    $BaseUrl = $env:LLMMAN_BASE_URL
    if (!$BaseUrl) { $BaseUrl = "https://github.com/$Repo/releases" }
    $Version = $env:LLMMAN_VERSION
    if ($Version) {
        $Url = "$BaseUrl/download/$Version/$Asset"
        "Version: $Version"
    } else {
        $Url = "$BaseUrl/latest/download/$Asset"
        "Version: latest"
    }

    $Dir = Join-Path ([System.IO.Path]::GetTempPath()) "llmman-install-$PID"
    New-Item -Path $Dir -Force -ItemType Directory | Out-Null
    try {
        $Tmp = Join-Path $Dir "llmman.exe"
        "Downloading $Asset..."
        try {
            Invoke-WebRequest -Uri $Url -OutFile $Tmp -UseBasicParsing
        } catch {
            Die "Failed to download $Url" `
                "(has a release for $Target been published yet? see .github/workflows/ci.yml)"
        }

        & $Tmp --version *> $null
        if ($LASTEXITCODE) {
            Die "Downloaded llmman binary failed to run"
        }

        if ($env:SKIP_INSTALL) {
            "Download verified, installation skipped (SKIP_INSTALL is set): $Tmp"
            return
        }

        $InstallDir = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps"
        $Dest = Join-Path $InstallDir "llmman.exe"
        if (Test-Path $Dest) {
            Remove-Item "$Dest.old" -Force -ErrorAction SilentlyContinue
            Move-Item $Dest "$Dest.old" -Force
        }
        Move-Item $Tmp $Dest -Force

        "Installation completed successfully"
    } finally {
        Remove-Item $Dir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Main
