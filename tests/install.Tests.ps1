# This suite requires only Windows PowerShell 5.1 and uses a disposable USERPROFILE.
$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('skill-maxx-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
$testRoot = [IO.Path]::GetFullPath($testRoot)
$fixture = Join-Path $testRoot 'source repo'
$project = Join-Path $testRoot 'project with spaces'
$testHome = Join-Path $testRoot 'test home'
foreach ($dir in @($fixture, $project, $testHome)) { New-Item -ItemType Directory -Path $dir | Out-Null }
Copy-Item -LiteralPath (Join-Path $repository 'scripts') -Destination $fixture -Recurse
Copy-Item -LiteralPath (Join-Path $repository 'skills') -Destination $fixture -Recurse
$installer = Join-Path $fixture 'scripts/install.ps1'
$script:checks = 0
function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
    $script:checks++
}
function Quote([string]$Value) { return "'" + $Value.Replace("'", "''") + "'" }
function Run-Installer([string]$Options = '', [bool]$ShouldFail = $false) {
    $command = '& ' + (Quote $installer) + ' ' + $Options
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = Join-Path $PSHOME 'powershell.exe'
    $info.Arguments = '-NoProfile -NonInteractive -EncodedCommand ' + [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    $info.WorkingDirectory = $project
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.EnvironmentVariables['USERPROFILE'] = $testHome
    $process = [Diagnostics.Process]::Start($info)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    Assert (($process.ExitCode -ne 0) -eq $ShouldFail) "Unexpected exit $($process.ExitCode): $Options`n$stdout`n$stderr"
    $process.Dispose()
    return $stdout
}
try {
    $null = Run-Installer '-Preview'
    Assert (-not (Test-Path -LiteralPath (Join-Path $project '.agents'))) 'Preview created files.'
    $null = Run-Installer
    foreach ($agentDir in @('.agents', '.claude')) {
        foreach ($skill in @('echo', 'progress-reporting')) {
            $actual = Join-Path $project "$agentDir/skills/$skill/SKILL.md"
            $expected = Join-Path $fixture "skills/$skill/SKILL.md"
            Assert ((Get-FileHash $actual).Hash -eq (Get-FileHash $expected).Hash) "Installed content differs: $actual"
        }
    }
    Assert ((Run-Installer) -match 'Unchanged:') 'Repeat install was not a no-op.'
    $echo = Join-Path $project '.agents/skills/echo/SKILL.md'
    Add-Content -LiteralPath $echo -Value 'Local edit.'
    $null = Run-Installer '' $true
    Assert ((Get-Content -LiteralPath $echo -Raw) -match 'Local edit') 'Conflict changed existing content.'
    $unrelated = Join-Path $project '.agents/skills/unrelated.txt'
    Set-Content -LiteralPath $unrelated -Value 'Keep me.'
    $null = Run-Installer '-Replace -Skills echo'
    Assert ((Get-FileHash $echo).Hash -eq (Get-FileHash (Join-Path $fixture 'skills/echo/SKILL.md')).Hash) 'Replacement failed.'
    Assert ((Get-Content $unrelated) -eq 'Keep me.') 'Replacement affected an unrelated file.'
    $null = Run-Installer '-Scope global -Agent codex -Skills echo'
    Assert (Test-Path -LiteralPath (Join-Path $testHome '.agents/skills/echo/SKILL.md')) 'Global Codex installation failed.'
    Assert (-not (Test-Path -LiteralPath (Join-Path $testHome '.claude'))) 'Agent selection was ignored.'
    Assert (-not (Test-Path -LiteralPath (Join-Path $testHome '.agents/skills/progress-reporting'))) 'Skill selection was ignored.'
    $null = Run-Installer '-Scope global -Agent claude-code -Skills echo,progress-reporting'
    Assert (Test-Path -LiteralPath (Join-Path $testHome '.claude/skills/progress-reporting/SKILL.md')) 'Combined skill selection failed.'
    $fresh = Join-Path $testRoot 'explicit project'
    New-Item -ItemType Directory -Path $fresh | Out-Null
    $null = Run-Installer ('-ProjectPath ' + (Quote $fresh) + ' -Skills echo,missing') $true
    Assert (-not (Test-Path -LiteralPath (Join-Path $fresh '.agents'))) 'Invalid selection partially installed.'
    $null = Run-Installer ('-ProjectPath ' + (Quote $fresh) + ' -Agent claude-code -Skills echo')
    Assert (Test-Path -LiteralPath (Join-Path $fresh '.claude/skills/echo/SKILL.md')) 'Explicit project installation failed.'
    foreach ($options in @('-Agent invalid', '-Scope invalid', '-Skills ../echo', '-Skills echo,', '-Scope global -ProjectPath .', '-ProjectPath does-not-exist')) {
        $null = Run-Installer $options $true
    }
    # A later conflict must prevent an earlier destination from being written.
    Add-Content -LiteralPath (Join-Path $fresh '.claude/skills/echo/SKILL.md') -Value 'Changed.'
    $null = Run-Installer ('-ProjectPath ' + (Quote $fresh) + ' -Skills echo') $true
    Assert (-not (Test-Path -LiteralPath (Join-Path $fresh '.agents'))) 'Destination validation partially installed.'
    $bad = Join-Path $fixture 'skills/echo/SKILL.md'
    Set-Content -LiteralPath $bad -Value 'Invalid metadata.'
    $null = Run-Installer '-Skills echo -Replace' $true
    Copy-Item -LiteralPath (Join-Path $repository 'skills/echo/SKILL.md') -Destination $bad -Force
    $null = Run-Installer ('-ProjectPath ' + (Quote (Join-Path $fixture 'skills/echo')) + ' -Skills echo -Replace') $true
    # Junction creation does not require Developer Mode or elevation on Windows.
    $linked = Join-Path $testRoot 'linked project'
    $outside = Join-Path $testRoot 'outside'
    New-Item -ItemType Directory -Path $linked, $outside | Out-Null
    $junction = Join-Path $linked '.agents'
    New-Item -ItemType Junction -Path $junction -Target $outside | Out-Null
    $null = Run-Installer ('-ProjectPath ' + (Quote $linked) + ' -Skills echo -Replace') $true
    Assert (@(Get-ChildItem -LiteralPath $outside -Force).Count -eq 0) 'Installer followed a junction.'
    [IO.Directory]::Delete($junction)
    # Whole-folder installation includes hidden files, nested resources, and empty directories.
    $resources = Join-Path $fixture 'skills/echo/references/empty'
    New-Item -ItemType Directory -Path $resources -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $fixture 'skills/echo/.resource') -Value 'Resource.'
    $null = Run-Installer '-Skills echo -Replace'
    Assert (Test-Path -LiteralPath (Join-Path $project '.agents/skills/echo/.resource')) 'Resource copy failed.'
    Assert (Test-Path -LiteralPath (Join-Path $project '.agents/skills/echo/references/empty')) 'Empty directory copy failed.'
    Write-Output "Passed $script:checks PowerShell installer checks."
}
finally {
    # Remove any surviving test junction itself before recursively deleting the fixture.
    if ($junction -and (Test-Path -LiteralPath $junction)) { [IO.Directory]::Delete($junction) }
    $parent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
    if ((Split-Path -Parent $testRoot) -ne $parent -or (Split-Path -Leaf $testRoot) -notlike 'skill-maxx-tests-*') { throw 'Unsafe test cleanup path.' }
    Remove-Item -LiteralPath $testRoot -Recurse -Force
}
