<#
.SYNOPSIS
This script creates a skill scaffold in this repository.
.DESCRIPTION
This script requires Windows PowerShell 5.1 or later and never overwrites an existing skill.
.PARAMETER Name
The required skill name uses lowercase letters, digits, and single hyphen separators.
.EXAMPLE
 .\scripts\newskill.ps1 my-new-skill
.EXAMPLE
 .\scripts\newskill.ps1 -Name my-new-skill
#>
[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Position = 0)][string]$Name
)
$ErrorActionPreference = 'Stop'

function Assert-NoLinks([string]$Path) {
    $cursor = [IO.Path]::GetFullPath($Path)
    while ($cursor) {
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
        if ($null -ne $item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw "The path contains a link or junction: $cursor"
        }
        $parent = [IO.Directory]::GetParent($cursor)
        if ($null -eq $parent) { break }
        $cursor = $parent.FullName
    }
}

try {
    if ([string]::IsNullOrEmpty($Name)) {
        throw 'You must supply one skill name. Usage: .\scripts\newskill.ps1 -Name my-new-skill'
    }
    if ($Name -cnotmatch '\A[a-z0-9]+(-[a-z0-9]+)*\z' -or $Name.Length -gt 64) {
        throw 'The skill name must use 1-64 lowercase letters or digits, with single hyphens between groups.'
    }
    if ($Name -match '\A(all|con|prn|aux|nul|com[1-9]|lpt[1-9])\z') {
        throw "The skill name is reserved: $Name"
    }

    $sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../skills'))
    Assert-NoLinks $sourceRoot
    if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
        throw "The repository skills directory is missing: $sourceRoot"
    }
    $destination = Join-Path $sourceRoot $Name
    Assert-NoLinks $destination
    if (Test-Path -LiteralPath $destination) {
        throw "The skill destination already exists: $destination"
    }

    # The ASCII script source also works with Windows PowerShell 5.1's default encoding.
    $dash = [char]0x2014
    $content = @(
        '---'
        "name: $Name"
        "description: TODO $dash Describe the skill and the requests that should activate it."
        '---'
        ''
        "# $Name"
        ''
        "TODO $dash Replace this paragraph with the skill instructions."
    ) -join "`n"
    $encoding = New-Object System.Text.UTF8Encoding($false)
    $bytes = $encoding.GetBytes($content + "`n")
    New-Item -ItemType Directory -Path $destination | Out-Null
    $entry = Join-Path $destination 'SKILL.md'
    $stream = [IO.File]::Open($entry, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) }
    finally { $stream.Dispose() }

    Write-Output "The new skill file is at: $entry"
    Write-Output 'You must replace both TODO placeholders in SKILL.md before installing the skill.'
    Write-Output 'You can install the skill for both agents in an existing project with the following command.'
    Write-Output 'You must replace [REPO DIR], [SKILL-NAME], and [PROJECT DIR] with your repository path, skill name, and target project path.'
    Write-Output "& '[REPO DIR]\scripts\install.ps1' -Skills '[SKILL-NAME]' -ProjectPath '[PROJECT DIR]'"
    exit 0
}
catch {
    [Console]::Error.WriteLine("Skill creation failed: $($_.Exception.Message)")
    exit 1
}
