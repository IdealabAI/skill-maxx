# Windows PowerShell 5.1 or later. No administrator access is required.
[CmdletBinding()]
param(
    [ValidateSet('codex', 'claude-code', 'both')][string]$Agent = 'both',
    [ValidateSet('project', 'global')][string]$Scope = 'project',
    [string[]]$Skills = @('all'),
    [string]$ProjectPath = (Get-Location).Path,
    [switch]$Preview,
    [switch]$Replace
)
$ErrorActionPreference = 'Stop'

function Assert-NoLinks([string]$Path) {
    $cursor = [IO.Path]::GetFullPath($Path)
    while ($cursor) {
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
        if ($null -ne $item) {
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Links and junctions are not supported: $cursor"
            }
        }
        $parent = [IO.Directory]::GetParent($cursor)
        if ($null -eq $parent) { break }
        $cursor = $parent.FullName
    }
}

function Get-TreeEntries([string]$Path) {
    foreach ($item in Get-ChildItem -LiteralPath $Path -Force) {
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw "Links and junctions are not supported: $($item.FullName)"
        }
        $item
        if ($item.PSIsContainer) { Get-TreeEntries $item.FullName }
    }
}

function Get-TreeSignature([string]$Path) {
    $root = (Get-Item -LiteralPath $Path).FullName.TrimEnd('\', '/')
    $lines = @(Get-TreeEntries $root | ForEach-Object {
        $relative = $_.FullName.Substring($root.Length + 1)
        if ($_.PSIsContainer) { "D:$relative" }
        else { "F:${relative}:$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)" }
    } | Sort-Object)
    return ($lines -join "`n")
}

try {
    if ($Scope -eq 'global' -and $PSBoundParameters.ContainsKey('ProjectPath')) {
        throw '-ProjectPath cannot be combined with global scope.'
    }
    $sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../skills'))
    Assert-NoLinks $sourceRoot
    if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) { throw "Missing skills directory: $sourceRoot" }
    $Skills = @($Skills | ForEach-Object { $_.Split(',') })
    if ($Skills.Count -eq 1 -and $Skills[0] -eq 'all') {
        $Skills = @(Get-ChildItem -LiteralPath $sourceRoot -Directory | Select-Object -ExpandProperty Name)
    }
    if ($Skills.Count -eq 0) { throw 'Select at least one skill.' }
    $Skills = @($Skills | Select-Object -Unique)
    $base = if ($Scope -eq 'global') { $env:USERPROFILE } else { $ProjectPath }
    if ([string]::IsNullOrWhiteSpace($base)) { throw 'The target project or USERPROFILE must be set.' }
    $base = [IO.Path]::GetFullPath($base)
    Assert-NoLinks $base
    if (-not (Test-Path -LiteralPath $base -PathType Container)) { throw "The target project or home directory must exist: $base" }
    $agents = if ($Agent -eq 'both') { @('codex', 'claude-code') } else { @($Agent) }
    $operations = @()
    foreach ($skill in $Skills) {
        if ($skill -cnotmatch '^[a-z0-9]+(-[a-z0-9]+)*$' -or $skill.Length -gt 64) { throw "Invalid skill name: $skill" }
        $source = Join-Path $sourceRoot $skill
        Assert-NoLinks $source
        $entry = Join-Path $source 'SKILL.md'
        if (-not (Test-Path -LiteralPath $entry -PathType Leaf)) { throw "Unknown or incomplete skill: $skill" }
        $content = Get-Content -LiteralPath $entry -Raw
        if ($content -cnotmatch ('\A---\r?\nname: ' + [regex]::Escape($skill) + '\r?\ndescription: [^\r\n]+\r?\n---(?:\r?\n|$)')) {
            throw "Invalid skill metadata: $entry"
        }
        $signature = Get-TreeSignature $source
        foreach ($targetAgent in $agents) {
            $relativeRoot = if ($targetAgent -eq 'codex') { '.agents/skills' } else { '.claude/skills' }
            $root = [IO.Path]::GetFullPath((Join-Path $base $relativeRoot))
            $destination = Join-Path $root $skill
            if ($destination.StartsWith($sourceRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
                $sourceRoot.StartsWith($destination + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
                $destination -eq $sourceRoot) { throw 'Source and destination skill trees must not overlap.' }
            Assert-NoLinks $destination
            $unchanged = $false
            if (Test-Path -LiteralPath $destination) {
                if (-not (Test-Path -LiteralPath $destination -PathType Container)) { throw "The destination is not a directory: $destination" }
                $unchanged = (Get-TreeSignature $destination) -ceq $signature
                if (-not $unchanged -and -not $Replace) { throw "Different content exists at $destination. Use -Replace to replace this skill." }
            }
            # Validate existing ancestors, including files where directories are required.
            $cursor = $root
            while ($cursor -and -not (Test-Path -LiteralPath $cursor)) { $cursor = Split-Path -Parent $cursor }
            if (-not (Test-Path -LiteralPath $cursor -PathType Container)) { throw "A destination parent is not a directory: $cursor" }
            $operations += [pscustomobject]@{ Source = $source; Root = $root; Destination = $destination; Unchanged = $unchanged }
        }
    }
    foreach ($op in $operations) {
        if ($op.Unchanged) { Write-Output "Unchanged: $($op.Destination)"; continue }
        if ($Preview) { Write-Output "Would install: $($op.Destination)"; continue }
        Assert-NoLinks $op.Destination
        New-Item -ItemType Directory -Path $op.Root -Force | Out-Null
        $stage = Join-Path $op.Root ('.skill-stage-' + [guid]::NewGuid().ToString('N'))
        $backup = Join-Path $op.Root ('.skill-backup-' + [guid]::NewGuid().ToString('N'))
        $committed = $false
        try {
            Copy-Item -LiteralPath $op.Source -Destination $stage -Recurse -Force
            if (Test-Path -LiteralPath $op.Destination) { Move-Item -LiteralPath $op.Destination -Destination $backup }
            try { Move-Item -LiteralPath $stage -Destination $op.Destination }
            catch {
                if (Test-Path -LiteralPath $backup) { Move-Item -LiteralPath $backup -Destination $op.Destination }
                throw
            }
            $committed = $true
            Write-Output "Installed: $($op.Destination)"
        }
        finally {
            foreach ($temporary in @($stage, $backup)) {
                # Only remove generated direct children of the validated skills root.
                if ((Split-Path -Parent ([IO.Path]::GetFullPath($temporary))) -ne $op.Root) { throw 'Unsafe cleanup path.' }
                if (Test-Path -LiteralPath $temporary) {
                    Assert-NoLinks $temporary
                    $null = @(Get-TreeEntries $temporary)
                    if ($temporary -eq $backup -and -not $committed) {
                        Write-Warning "Recovery copy retained at $backup"
                    } else { Remove-Item -LiteralPath $temporary -Recurse -Force }
                }
            }
        }
    }
    exit 0
}
catch {
    [Console]::Error.WriteLine("Installation failed: $($_.Exception.Message)")
    exit 1
}
