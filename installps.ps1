# ============================================================
# local-claude installer (PowerShell)
# Configure Claude Code to use any LLM server
# ============================================================

param(
    [switch]$Uninstall,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

# --- Constants ---

$ConfigDir = Join-Path $env:USERPROFILE ".claude"
$ConfigFile = Join-Path $ConfigDir "localllm.json"
$AliasName = "local-claude"
$ProfileMarker = "# --- local-claude function (added by local-claude installer) ---"

# --- Utility Functions ---

function Print-Header {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "   local-claude installer" -ForegroundColor Cyan
    Write-Host "   Use Claude Code with any LLM server" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
}

function Print-Step {
    param([int]$Current, [int]$Total, [string]$Message)
    Write-Host "[$Current/$Total] " -ForegroundColor Cyan -NoNewline
    Write-Host $Message
}

function Print-Success {
    param([string]$Message)
    Write-Host "  [ok] " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Print-Warn {
    param([string]$Message)
    Write-Host "  [!] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Print-Error {
    param([string]$Message)
    Write-Host "  [error] " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

function Prompt-Input {
    param([string]$PromptText, [string]$Default = "")

    if ($Default) {
        Write-Host "> $PromptText [$Default]: " -ForegroundColor Cyan -NoNewline
    } else {
        Write-Host "> ${PromptText}: " -ForegroundColor Cyan -NoNewline
    }

    $result = Read-Host
    if ([string]::IsNullOrWhiteSpace($result) -and $Default) {
        return $Default
    }
    return $result
}

function Validate-Url {
    param([string]$Url)
    return $Url -match "^https?://\S+"
}

function Generate-Config {
    param(
        [string]$Url,
        [string]$ApiKey,
        [string]$Model,
        [string]$Timeout
    )

    $apiKeyLine = ""
    if ($ApiKey) {
        $apiKeyLine = "        `"ANTHROPIC_API_KEY`": `"$ApiKey`",`n"
    }

    return @"
{
    "env": {
        "ANTHROPIC_BASE_URL": "$Url",
$apiKeyLine        "API_TIMEOUT_MS": "$Timeout",
        "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": 1,
        "ANTHROPIC_MODEL": "$Model",
        "ANTHROPIC_SMALL_FAST_MODEL": "$Model",
        "ANTHROPIC_DEFAULT_SONNET_MODEL": "$Model",
        "ANTHROPIC_DEFAULT_OPUS_MODEL": "$Model",
        "ANTHROPIC_DEFAULT_HAIKU_MODEL": "$Model"
    }
}
"@
}

# --- Install ---

function Do-Install {
    Print-Header

    Write-Host "Checking prerequisites..." -NoNewline:$false

    # Check if ~/.claude/ exists
    if (-not (Test-Path $ConfigDir -PathType Container)) {
        Print-Error "Directory $ConfigDir not found."
        Write-Host ""
        Write-Host "  Claude Code does not appear to be installed."
        Write-Host "  Install it using one of the following commands:"
        Write-Host ""
        Write-Host "  PowerShell:" -ForegroundColor Cyan
        Write-Host "    irm https://claude.ai/install.ps1 | iex"
        Write-Host ""
        Write-Host "  Mac / Linux / WSL:" -ForegroundColor Cyan
        Write-Host "    curl -fsSL https://claude.ai/install.sh | bash"
        Write-Host ""

        Write-Host "> Would you like to install Claude Code now? [Y/n]: " -ForegroundColor Cyan -NoNewline
        $doInstall = Read-Host
        if ($doInstall -match "^[nN]$") {
            Write-Host "Aborted. Install Claude Code first and run this script again." -ForegroundColor Yellow
            exit 1
        }

        Write-Host ""
        Write-Host "Installing Claude Code..." -NoNewline:$false
        Invoke-Expression (Invoke-RestMethod https://claude.ai/install.ps1)

        if (-not (Test-Path $ConfigDir -PathType Container)) {
            Print-Error "Installation failed. $ConfigDir still not found."
            exit 1
        }
        Print-Success "Claude Code installed successfully"
    } else {
        Print-Success "$ConfigDir directory found"
    }

    # Check existing config
    if (Test-Path $ConfigFile) {
        Print-Warn "Config already exists at $ConfigFile"
        Write-Host "> Overwrite? [y/N]: " -ForegroundColor Cyan -NoNewline
        $overwrite = Read-Host
        if ($overwrite -notmatch "^[yY]$") {
            Write-Host "Aborted." -ForegroundColor Yellow
            exit 0
        }
    }

    Write-Host ""

    # Step 1: Server URL
    $totalSteps = 3
    $attempts = 0

    Print-Step 1 $totalSteps "LLM Server URL"
    Write-Host "  Enter the base URL of your LLM server."
    Write-Host "  Example: " -NoNewline
    Write-Host "http://192.168.1.1:1234" -ForegroundColor Cyan

    $serverUrl = ""
    while ($true) {
        $serverUrl = Prompt-Input "Server URL" "http://localhost:1234"
        if (Validate-Url $serverUrl) {
            break
        }
        $attempts++
        if ($attempts -ge 3) {
            Print-Error "Invalid URL after 3 attempts. Aborting."
            exit 1
        }
        Print-Error "Invalid URL. Must start with http:// or https://"
    }
    Write-Host ""

    # Step 2: API Key
    Print-Step 2 $totalSteps "API Key (optional)"
    Write-Host "  If your server requires an API key, enter it below."
    Write-Host "  Leave blank to skip."
    $apiKey = Prompt-Input "API Key" ""
    Write-Host ""

    # Step 3: Model Name
    Print-Step 3 $totalSteps "Model Name"
    Write-Host "  Enter the model identifier your server exposes."
    Write-Host "  This will be used for all Claude model slots."
    $modelName = Prompt-Input "Model name" "default_model"
    Write-Host ""

    # Generate config
    $timeout = "3000000"
    Write-Host "Generating config..."
    $config = Generate-Config -Url $serverUrl -ApiKey $apiKey -Model $modelName -Timeout $timeout
    $config | Out-File -FilePath $ConfigFile -Encoding utf8 -NoNewline
    Print-Success "Written to $ConfigFile"
    Write-Host ""

    # Launcher setup
    Write-Host "How would you like to launch local-claude?"
    Write-Host "  [1] " -ForegroundColor Cyan -NoNewline
    Write-Host "PowerShell function (adds '$AliasName' to your `$PROFILE)"
    Write-Host "  [2] " -ForegroundColor Cyan -NoNewline
    Write-Host "Launcher script (creates local-claude.ps1 next to this script)"
    Write-Host "  [3] " -ForegroundColor Cyan -NoNewline
    Write-Host "Skip (I'll run it manually)"

    $choice = Prompt-Input "Choice" "1"
    Write-Host ""

    switch ($choice) {
        "1" {
            # Ensure $PROFILE exists
            $profileDir = Split-Path $PROFILE -Parent
            if (-not (Test-Path $profileDir)) {
                New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
            }
            if (-not (Test-Path $PROFILE)) {
                New-Item -ItemType File -Path $PROFILE -Force | Out-Null
            }

            $functionBlock = @"

$ProfileMarker
function $AliasName { claude --settings "$ConfigFile" @args }
"@
            # Check if already exists
            $profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
            if ($profileContent -and $profileContent.Contains($AliasName)) {
                Print-Warn "Function already exists in $PROFILE, updating..."
                $lines = Get-Content $PROFILE
                $filtered = $lines | Where-Object {
                    $_ -notmatch $ProfileMarker -and $_ -notmatch "function $AliasName"
                }
                $filtered | Set-Content $PROFILE
            }

            Add-Content -Path $PROFILE -Value $functionBlock
            Print-Success "Function added to $PROFILE"
            Write-Host "  Run: " -NoNewline
            Write-Host ". `$PROFILE" -ForegroundColor Cyan
        }
        "2" {
            $scriptDir = Split-Path $MyInvocation.ScriptName -Parent
            if (-not $scriptDir) { $scriptDir = Get-Location }
            $launcherFile = Join-Path $scriptDir "local-claude.ps1"

            $launcherContent = @"
# local-claude launcher
claude --settings "$ConfigFile" @args
"@
            $launcherContent | Out-File -FilePath $launcherFile -Encoding utf8
            Print-Success "Launcher created at $launcherFile"
        }
        "3" {
            Print-Success "Skipped launcher setup."
            Write-Host "  Run manually: " -NoNewline
            Write-Host "claude --settings $ConfigFile" -ForegroundColor Cyan
        }
        default {
            Print-Warn "Invalid choice, skipping launcher setup."
            Write-Host "  Run manually: " -NoNewline
            Write-Host "claude --settings $ConfigFile" -ForegroundColor Cyan
        }
    }

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "  Installation complete!" -ForegroundColor Green
    Write-Host "  Run '$AliasName' to start." -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""
}

# --- Uninstall ---

function Do-Uninstall {
    Print-Header
    Write-Host "Uninstalling local-claude..."
    Write-Host ""

    # Remove config
    if (Test-Path $ConfigFile) {
        Remove-Item $ConfigFile -Force
        Print-Success "Removed $ConfigFile"
    } else {
        Print-Warn "$ConfigFile not found, skipping."
    }

    # Remove function from $PROFILE
    if ((Test-Path $PROFILE) -and (Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue) -match $AliasName) {
        $lines = Get-Content $PROFILE
        $filtered = $lines | Where-Object {
            $_ -notmatch [regex]::Escape($ProfileMarker) -and $_ -notmatch "function $AliasName"
        }
        $filtered | Set-Content $PROFILE
        Print-Success "Removed function from $PROFILE"
    } else {
        Print-Warn "No function found in $PROFILE"
    }

    # Remove launcher script if it exists next to this script
    $scriptDir = Split-Path $MyInvocation.ScriptName -Parent
    if ($scriptDir) {
        $launcherFile = Join-Path $scriptDir "local-claude.ps1"
        if (Test-Path $launcherFile) {
            Remove-Item $launcherFile -Force
            Print-Success "Removed $launcherFile"
        }
    }

    Write-Host ""
    Write-Host "Uninstall complete." -ForegroundColor Green
    Write-Host ""
}

# --- Help ---

function Show-Help {
    Write-Host "Usage: .\installps.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Uninstall    Remove local-claude configuration and functions"
    Write-Host "  -Help         Show this help message"
    Write-Host ""
    Write-Host "With no options, runs the interactive installer."
}

# --- Entry Point ---

if ($Help) {
    Show-Help
} elseif ($Uninstall) {
    Do-Uninstall
} else {
    Do-Install
}
