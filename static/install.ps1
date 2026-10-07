# llmman installer (Windows) — downloads the llmman.exe binary matching
# this host's CPU architecture from GitHub Releases and installs it to
# %LOCALAPPDATA%\Microsoft\WindowsApps, which is already on PATH for every
# user account by default on Windows 10/11. For Linux/macOS, use
# install.sh instead.
#
#   irm https://llmmanorg.github.io/install.ps1 | iex
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

function Main {
    $Repo = $env:LLMMAN_REPO
    if (!$Repo) { $Repo = "llmmanorg/llmman" }

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
        $ChecksumUrl = "$BaseUrl/download/$Version/checksums.txt"
        "Version: $Version"
    } else {
        $Url = "$BaseUrl/latest/download/$Asset"
        $ChecksumUrl = "$BaseUrl/latest/download/checksums.txt"
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

        $Checksums = Join-Path $Dir "checksums.txt"
        "Downloading checksums.txt..."
        try {
            Invoke-WebRequest -Uri $ChecksumUrl -OutFile $Checksums -UseBasicParsing
        } catch {
            Die "Failed to download $ChecksumUrl"
        }

        $ChecksumEntries = @()
        foreach ($Line in Get-Content -LiteralPath $Checksums) {
            $Parts = @($Line.Trim() -split '\s+')
            if ($Parts.Count -ge 2 -and $Parts[-1] -ceq $Asset) {
                $ChecksumEntries += ,$Parts
            }
        }
        if ($ChecksumEntries.Count -ne 1 -or
            $ChecksumEntries[0].Count -ne 2 -or
            ![regex]::IsMatch($ChecksumEntries[0][0], '^[0-9A-Fa-f]{64}$')) {
            Die "checksums.txt must contain exactly one valid SHA-256 entry for $Asset"
        }

        $Expected = $ChecksumEntries[0][0].ToLowerInvariant()
        try {
            $Actual = (Get-FileHash -LiteralPath $Tmp -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
        } catch {
            Die "Failed to calculate the SHA-256 checksum for $Asset"
        }
        if ($Actual -cne $Expected) {
            Die "Checksum verification failed for $Asset" `
                "Expected: $Expected" `
                "Actual:   $Actual"
        }
        "Checksum verified for $Asset."

        & $Tmp --version *> $null
        if ($LASTEXITCODE) {
            Die "Downloaded llmman binary failed to run"
        }

        if ($env:SKIP_INSTALL) {
            "Download and checksum verified; installation skipped (SKIP_INSTALL is set): $Tmp"
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
