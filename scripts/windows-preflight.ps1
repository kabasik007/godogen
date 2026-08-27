[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$Failures = New-Object System.Collections.Generic.List[string]
$Warnings = New-Object System.Collections.Generic.List[string]

function Add-Failure([string]$Message) {
    $script:Failures.Add($Message)
    Write-Host "[FAIL] $Message" -ForegroundColor Red
}

function Add-Warning([string]$Message) {
    $script:Warnings.Add($Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Add-Ok([string]$Message) {
    Write-Host "[ OK ] $Message" -ForegroundColor Green
}

if ($env:OS -ne "Windows_NT") {
    Add-Failure "This preflight script is for native Windows PowerShell."
}

# Python 3
$python = Get-Command python -ErrorAction SilentlyContinue
$py = Get-Command py -ErrorAction SilentlyContinue
if ($python) {
    $pythonVersion = (& $python.Source --version 2>&1 | Out-String).Trim()
    Add-Ok "Python: $pythonVersion ($($python.Source))"
}
elif ($py) {
    $pythonVersion = (& $py.Source -3 --version 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -eq 0) {
        Add-Ok "Python: $pythonVersion via py -3 ($($py.Source))"
    }
    else {
        Add-Failure "The Python launcher exists, but 'py -3' failed. Install Python 3.10+."
    }
}
else {
    Add-Failure "Python 3 is not on PATH as 'python' or 'py'."
}

# .NET SDK
$dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
if (-not $dotnet) {
    Add-Failure ".NET SDK is not on PATH. Godogen's current Godot C# flow expects .NET 9."
}
else {
    $dotnetVersion = (& $dotnet.Source --version 2>&1 | Out-String).Trim()
    $major = 0
    if ($dotnetVersion -match '^(\d+)\.') {
        $major = [int]$Matches[1]
    }
    if ($major -lt 9) {
        Add-Failure ".NET SDK $dotnetVersion detected; install .NET 9 SDK."
    }
    else {
        Add-Ok ".NET SDK: $dotnetVersion ($($dotnet.Source))"
    }
}

# Codex CLI
$codex = Get-Command codex -ErrorAction SilentlyContinue
if (-not $codex) {
    Add-Failure "Codex CLI is not on PATH. Start Codex only after the local CLI is installed and authenticated."
}
else {
    $codexVersion = (& $codex.Source --version 2>&1 | Out-String).Trim()
    Add-Ok "Codex: $codexVersion ($($codex.Source))"
}

# Git is strongly recommended but publish.ps1 can still produce a target without it.
$git = Get-Command git -ErrorAction SilentlyContinue
if ($git) {
    $gitVersion = (& $git.Source --version 2>&1 | Out-String).Trim()
    Add-Ok "Git: $gitVersion ($($git.Source))"
}
else {
    Add-Warning "Git is not on PATH; published projects will not be initialized as Git repositories."
}

# Godot .NET / Mono build
$godot = Get-Command godot -ErrorAction SilentlyContinue
if (-not $godot) {
    Add-Failure "Godot is not callable as 'godot'. The desktop app may be installed, but Codex needs the .NET executable on PATH."

    $wingetPackages = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
    if (Test-Path -LiteralPath $wingetPackages) {
        $candidate = Get-ChildItem -LiteralPath $wingetPackages -Directory -Filter "GodotEngine.GodotEngine.Mono_*" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            ForEach-Object {
                Get-ChildItem -LiteralPath $_.FullName -File -Recurse -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -match 'mono_.*win.*\.exe$' -and $_.Name -notmatch '_console\.exe$' } |
                    Select-Object -First 1
            } |
            Select-Object -First 1

        if ($candidate) {
            Add-Warning "A WinGet Godot Mono executable appears to exist here: $($candidate.FullName)"
            Write-Host "       Put its directory on PATH, then open a new PowerShell window and rerun this script."
        }
    }
}
else {
    $godotVersion = (& $godot.Source --version 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) {
        Add-Failure "'godot --version' failed: $godotVersion"
    }
    elseif ($godotVersion -notmatch '(?i)mono') {
        Add-Failure "Godot reports '$godotVersion'. Godogen requires the .NET/Mono build, not the standard build."
    }
    else {
        Add-Ok "Godot: $godotVersion ($($godot.Source))"

        $headlessOutput = (& $godot.Source --headless --quit 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -ne 0) {
            Add-Failure "Godot .NET headless startup failed."
            if ($headlessOutput -match '(?i)assemblies not found|GodotSharp') {
                Add-Warning "GodotSharp/.NET assemblies are not being resolved. Do not move only godot.exe away from its GodotSharp directory. If this is a WinGet portable alias, try the real installed executable or reinstall the Mono package."
            }
            if ($headlessOutput) {
                Write-Host $headlessOutput
            }
        }
        else {
            Add-Ok "Godot headless startup succeeds."
        }
    }
}

# Optional proof/capture tooling.
$ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
if ($ffmpeg) {
    Add-Ok "ffmpeg: $($ffmpeg.Source)"
}
else {
    Add-Warning "ffmpeg is not on PATH; game generation can start, but proof-video encoding will fail later."
}

$magick = Get-Command magick -ErrorAction SilentlyContinue
if ($magick) {
    Add-Ok "ImageMagick: $($magick.Source)"
}
else {
    Add-Warning "ImageMagick ('magick') is not on PATH; only asset workflows that resize/crop images need it."
}

Write-Host ""
Write-Host "Preflight summary: $($Failures.Count) failure(s), $($Warnings.Count) warning(s)."
if ($Failures.Count -gt 0) {
    Write-Host "Fix the failures before starting a Godot + Codex generation run." -ForegroundColor Red
    exit 1
}

Write-Host "Windows environment is ready for the Godot + Codex smoke test." -ForegroundColor Green
exit 0
