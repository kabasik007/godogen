[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("godot", "bevy", "babylon")]
    [string]$Engine,

    [Parameter(Mandatory = $true)]
    [ValidateSet("claude", "codex")]
    [string]$Agent,

    [Parameter(Mandatory = $true)]
    [string]$Out,

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Helpers = Join-Path $RepoRoot "scripts"

function Resolve-Python {
    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($python) {
        return [pscustomobject]@{ Exe = $python.Source; Prefix = @(); Display = "python" }
    }

    $py = Get-Command py -ErrorAction SilentlyContinue
    if ($py) {
        return [pscustomobject]@{ Exe = $py.Source; Prefix = @("-3"); Display = "py -3" }
    }

    throw "Python 3 is required. Install Python 3.10+ and ensure either 'python' or 'py' is on PATH."
}

function Invoke-Python {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Python,
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $AllArguments = @($Python.Prefix) + $Arguments
    & $Python.Exe @AllArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Python helper failed with exit code $LASTEXITCODE."
    }
}

$Python = Resolve-Python

switch ($Engine) {
    "godot" {
        $EngineDisplay = "Godot"
        $RuntimeAssetDir = "assets"
    }
    "bevy" {
        $EngineDisplay = "Bevy"
        $RuntimeAssetDir = "assets"
    }
    "babylon" {
        $EngineDisplay = "Babylon.js"
        $RuntimeAssetDir = "src/assets"
    }
}

switch ($Agent) {
    "claude" {
        $Manifest = "CLAUDE.md"
        $SkillsDirRel = ".claude/skills"
        $AgentName = "Claude"
        $AssetSkillCommand = "/asset-gen"
    }
    "codex" {
        $Manifest = "AGENTS.md"
        $SkillsDirRel = ".agents/skills"
        $AgentName = "Codex"
        $AssetSkillCommand = '$asset-gen'
    }
}

$AssetGenSkillDir = "$SkillsDirRel/asset-gen"
$EngineGuideFile = "$Engine.md"
$Target = [System.IO.Path]::GetFullPath($Out)
$RepoFull = [System.IO.Path]::GetFullPath($RepoRoot)

if ($Force -and $Target.TrimEnd('\') -ieq $RepoFull.TrimEnd('\')) {
    throw "Refusing to use -Force with the Godogen source repository as the target."
}

if ($Force -and (Test-Path -LiteralPath $Target)) {
    Write-Host "Force: cleaning $Target"
    Remove-Item -LiteralPath $Target -Recurse -Force
}

New-Item -ItemType Directory -Path $Target -Force | Out-Null

$TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("godogen-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $TempRoot -Force | Out-Null

try {
    Write-Host "Publishing $Engine/$Agent to: $Target"

    # --- Skills: only the asset-gen skill ---
    $TempSkills = Join-Path $TempRoot "skills"
    $TempAssetSkill = Join-Path $TempSkills "asset-gen"
    New-Item -ItemType Directory -Path $TempAssetSkill -Force | Out-Null
    Copy-Item -Path (Join-Path $RepoRoot "asset-gen\*") -Destination $TempAssetSkill -Recurse -Force

    Get-ChildItem -Path $TempAssetSkill -Directory -Filter "__pycache__" -Recurse -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force

    Invoke-Python -Python $Python -Arguments @(
        (Join-Path $Helpers "render_dir.py"),
        $TempSkills,
        "AGENT_NAME=$AgentName",
        "ASSET_GEN_SKILL_DIR=$AssetGenSkillDir",
        "ASSET_SKILL_COMMAND=$AssetSkillCommand",
        "RUNTIME_ASSET_DIR=$RuntimeAssetDir",
        "PYTHON_CMD=$($Python.Display)"
    )

    if ($Agent -eq "codex") {
        Invoke-Python -Python $Python -Arguments @(
            (Join-Path $Helpers "generate_codex_metadata.py"),
            $TempSkills
        )
    }

    $SkillsDest = Join-Path $Target ($SkillsDirRel -replace '/', '\')
    New-Item -ItemType Directory -Path $SkillsDest -Force | Out-Null
    $TargetAssetSkill = Join-Path $SkillsDest "asset-gen"
    if (Test-Path -LiteralPath $TargetAssetSkill) {
        Remove-Item -LiteralPath $TargetAssetSkill -Recurse -Force
    }
    Copy-Item -Path $TempAssetSkill -Destination $SkillsDest -Recurse -Force
    Write-Host "Installed asset-gen skill"

    # --- Manifest: the runtime process doc ---
    $ManifestTemp = Join-Path $TempRoot "manifest"
    New-Item -ItemType Directory -Path $ManifestTemp -Force | Out-Null
    $ManifestTempFile = Join-Path $ManifestTemp $Manifest
    Copy-Item -LiteralPath (Join-Path $RepoRoot "prompts\runtime.md") -Destination $ManifestTempFile -Force

    Invoke-Python -Python $Python -Arguments @(
        (Join-Path $Helpers "render_dir.py"),
        $ManifestTemp,
        "ENGINE_NAME=$EngineDisplay",
        "ENGINE_GUIDE_FILE=$EngineGuideFile",
        "ASSET_SKILL_COMMAND=$AssetSkillCommand"
    )

    Copy-Item -LiteralPath $ManifestTempFile -Destination (Join-Path $Target $Manifest) -Force
    Write-Host "Created $Manifest"

    # --- Per-engine guide ---
    Copy-Item -LiteralPath (Join-Path $RepoRoot "engines\$Engine.md") -Destination (Join-Path $Target $EngineGuideFile) -Force
    Write-Host "Created $EngineGuideFile"

    # --- .gitignore ---
    $GitIgnorePath = Join-Path $Target ".gitignore"
    if (-not (Test-Path -LiteralPath $GitIgnorePath)) {
        $Lines = New-Object System.Collections.Generic.List[string]
        if ($Agent -eq "claude") {
            $Lines.Add(".claude")
            $Lines.Add("CLAUDE.md")
        }
        else {
            $Lines.Add(".agents")
            $Lines.Add("AGENTS.md")
            $Lines.Add(".codex")
        }
        $Lines.Add($EngineGuideFile)

        switch ($Engine) {
            "godot" {
                @("assets", "screenshots", ".godot", "*.import", "bin/", "obj/") | ForEach-Object { $Lines.Add($_) }
            }
            "bevy" {
                @("/target", "/screenshots") | ForEach-Object { $Lines.Add($_) }
            }
            "babylon" {
                @("/node_modules", "/dist", "screenshots") | ForEach-Object { $Lines.Add($_) }
            }
        }

        [System.IO.File]::WriteAllLines($GitIgnorePath, $Lines, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "Created .gitignore"
    }

    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
        & $git.Source -C $Target init -q 2>$null
    }
    else {
        Write-Warning "git is not on PATH; target was published but not initialized as a Git repository."
    }

    if ($Agent -eq "codex" -and -not (Get-Command codex -ErrorAction SilentlyContinue)) {
        Write-Warning "Codex CLI is not on PATH. Publish succeeded, but run 'codex' only after installing/configuring the local Codex CLI."
    }

    if ($Engine -eq "godot") {
        $godot = Get-Command godot -ErrorAction SilentlyContinue
        if (-not $godot) {
            Write-Warning "Godot is not available as 'godot' on PATH. Codex will not be able to validate or run the generated project until the Godot .NET executable is on PATH."
        }
    }

    Write-Host "Done."
    Write-Host "Next: cd `"$Target`""
    if ($Agent -eq "codex") {
        Write-Host "Then: codex"
    }
}
finally {
    if (Test-Path -LiteralPath $TempRoot) {
        Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
