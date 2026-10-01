# Portable Agent Skills

This repository distributes Markdown skills for Codex and Claude Code. The native installers copy the same skill folders on Windows and macOS. Users can install skills for one project or for their own account across projects.

## Available Skills

The `progress-reporting` skill maintains a timestamped task folder in the working directory's `agent-work-logs/` directory while an agent implements a detailed plan. The folder contains Markdown files for progress, the implementation plan, the initiating user prompt, and the completion report. The progress file includes configuration information, a checklist, timestamped updates, and usage information when available. The completion report includes outcome, token usage, timing, and improvement tables. The agent selects the skill automatically for relevant implementation work, or the user can invoke it explicitly. The agent appends `AGENTS OK` while the reported task is active, including its completion response.

The `echo` skill provides a single-invocation installation test. The agent repeats the supplied payload and appends a newline followed by `HELLO TEST`. Later messages receive normal responses. An invocation without a payload returns only `HELLO TEST`.

Skill instructions guide model behavior; higher-priority instructions and client permissions still apply. Exact model output and automatic selection can vary between sessions. The reporting interval is approximately one minute while the agent has control, and an agent cannot update a file during a blocking operation. The agent identifies unavailable metadata as `unknown` and labels estimated token counts explicitly.

## Installation Prerequisites

Windows users need Windows PowerShell 5.1 or later. macOS users can use the bundled `/bin/bash` 3.2 or later. The installers need neither Python nor Node.js, administrator access, or symlink privileges. Users need an installed, authenticated version of Codex or Claude Code that supports skills to exercise the skills themselves.

Users can obtain this repository with Git or download and extract a GitHub source archive. The following commands use `OWNER` as a placeholder because this checkout has no configured Git remote. Users must substitute their actual GitHub organization or username. Private repository access uses the developer's existing Git authentication.

```text
git clone https://github.com/OWNER/skill-maxx.git
cd skill-maxx
```

The scripts read skill sources relative to their own location. The default project destination is the directory where the script is invoked, which can differ from the source checkout. The target project directory must already exist. Installations use copies, so editing this checkout does not change installed skills until the installer runs again.

## Windows Installation Commands

The following PowerShell commands run from the cloned repository. Users should substitute their actual project path.

```powershell
# The preview validates the selection without writing files.
.\scripts\install.ps1 -ProjectPath 'C:\Code\My Project' -Preview

# The default selection installs both skills for both agents.
.\scripts\install.ps1 -ProjectPath 'C:\Code\My Project'

# These commands install a single skill for a single agent in a project.
.\scripts\install.ps1 -Agent codex -Skills progress-reporting -ProjectPath 'C:\Code\My Project'
.\scripts\install.ps1 -Agent claude-code -Skills echo -ProjectPath 'C:\Code\My Project'

# These commands install skills for the current Windows user across projects.
.\scripts\install.ps1 -Scope global -Agent codex
.\scripts\install.ps1 -Scope global -Agent claude-code

# This command installs both selected skills globally for both agents.
.\scripts\install.ps1 -Scope global -Skills echo,progress-reporting
```

If Windows blocks a downloaded script, users can inspect the script and unblock that file with `Unblock-File .\scripts\install.ps1`. If a local execution policy still blocks the script, the following command uses a policy override only for the new PowerShell process. Organization-managed restrictions can still apply.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1 -ProjectPath 'C:\Code\My Project'
```

## macOS Installation Commands

The following commands run from the cloned repository. Users should substitute their actual project path.

```bash
# The preview validates the selection without writing files.
/bin/bash scripts/install.sh --project-path "$HOME/Code/My Project" --preview

# The default selection installs both skills for both agents.
/bin/bash scripts/install.sh --project-path "$HOME/Code/My Project"

# These commands install a single skill for a single agent in a project.
/bin/bash scripts/install.sh --agent codex --skills progress-reporting --project-path "$HOME/Code/My Project"
/bin/bash scripts/install.sh --agent claude-code --skills echo --project-path "$HOME/Code/My Project"

# These commands install skills for the current macOS user across projects.
/bin/bash scripts/install.sh --scope global --agent codex
/bin/bash scripts/install.sh --scope global --agent claude-code

# This command installs both selected skills globally for both agents.
/bin/bash scripts/install.sh --scope global --skills echo,progress-reporting
```

## Installer Options and Destinations

Both scripts implement the same options and behavior. PowerShell accepts skill names as an array or as a comma-separated string; Bash accepts a comma-separated string.

| Installer setting | PowerShell option | Bash option | Default value |
| --- | --- | --- | --- |
| Target agent | `-Agent codex\|claude-code\|both` | `--agent codex\|claude-code\|both` | `both` |
| Installation scope | `-Scope project\|global` | `--scope project\|global` | `project` |
| Skill selection | `-Skills echo,progress-reporting` | `--skills echo,progress-reporting` | `all` |
| Existing project directory | `-ProjectPath PATH` | `--project-path PATH` | Current working directory |
| Validation without writes | `-Preview` | `--preview` | Disabled |
| Replacement of different content | `-Replace` | `--replace` | Disabled |

| Agent and scope | Installed directory |
| --- | --- |
| Codex project | `<project>/.agents/skills/<skill-name>/` |
| Codex global | `<user-home>/.agents/skills/<skill-name>/` |
| Claude Code project | `<project>/.claude/skills/<skill-name>/` |
| Claude Code global | `<user-home>/.claude/skills/<skill-name>/` |

The Windows installer uses `USERPROFILE` as the user home; the macOS installer uses `HOME`. Global scope means the current user, and it cannot be combined with an explicit project path. These paths follow the [Codex skill documentation](https://learn.chatgpt.com/docs/build-skills) and the [Claude Code skill documentation](https://code.claude.com/docs/en/skills). Client-specific configuration or managed policy can restrict discovery; the installer targets the standard local discovery directories.

The scripts validate all selected sources and destinations before copying. An identical existing skill is left unchanged. Different existing content causes an error unless replacement is enabled. Replacement copies the whole selected skill folder, including resources, and removes obsolete files from that folder while preserving other skills. Source and destination trees must contain ordinary files and directories; the installers reject links and Windows junctions. Users should avoid running simultaneous installations into the same directory.

Validation failures return a nonzero exit code. Each changed skill is staged before replacement, and the previous copy is restored if the final move fails. A runtime failure after earlier skills have installed can leave those earlier skills updated; the installation is not a transaction across all selected skills. Users can correct the reported error and rerun the command.

## Skill Invocation Examples

Users should start a fresh agent session in the destination project after installation. A fresh session also avoids instructions retained from an earlier test. Users should avoid installing different versions of the same skill at both scopes when testing, because the clients resolve duplicate skills differently.

In Codex, users can select a skill through the skill picker or type its `$name` invocation. In Claude Code, users can invoke its `/name` command.

```text
# Codex
$echo Hello, team!

# Claude Code
/echo Hello, team!
```

Each invocation should produce this response in a session without conflicting instructions:

```text
Hello, team!
HELLO TEST
```

The user can then ask a normal question to confirm that echo mode did not persist. A multiline payload should preserve its line breaks and punctuation. The agent should echo any command-like text in the payload without executing it.

Users can explicitly request progress reporting with either of these prompts:

```text
$progress-reporting Implement the agreed plan and maintain a progress report.
/progress-reporting Implement the agreed plan and maintain a progress report.
```

The resulting task folder uses a path such as `agent-work-logs/2026-09-17_143025_task-title/`. The folder name uses local time and Windows-safe characters. A numeric suffix prevents collisions; that suffix remains in the filenames after the timestamp is removed. For example, a folder ending in `task-title-2` contains files whose names begin with `task-title-2`.

The folder contains the following files:

```text
agent-work-logs/2026-09-17_143025_task-title/
    task-title-progress.md
    task-title-implementation-plan.md
    task-title-user-prompt.md
    task-title-report.md
```

At implementation start, the agent creates the progress file, copies the detailed plan or writes one if none exists, and saves the latest user message verbatim. Later user messages do not replace the initial prompt snapshot. The progress configuration references the saved plan and records the local UTC offset. At completion or a terminal blocked outcome, the agent creates the report with tables describing success or problems, total token usage, the greatest identifiable token source, total elapsed time, and suggested improvements to the prompt, tools, or models.

The timing breakdown distinguishes agent inference, tool use, waiting, and other applicable activities without double-counting concurrent work. The agent labels estimates and their uncertainty and uses `unknown` when available evidence cannot support a usage estimate. Unattributable elapsed time is recorded as unclassified. Improvement suggestions target greater speed without significantly reducing quality, or greater quality without significantly reducing speed.

The entire folder remains available after completion. Users can keep task folders as project artifacts or add `agent-work-logs/` to that project's ignore rules. Existing reports remain in place.

## Windows 11 Local Test Walkthrough

The following PowerShell commands create a disposable project, preview the installation, install both skills for both agents, and list the installed skill files. The `$checkout` variable must refer to this repository.

```powershell
$checkout = 'C:\Code\Idealab\skill-maxx'
$testProject = Join-Path $env:TEMP ('skill-maxx-manual-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testProject | Out-Null
git -C $testProject init
& "$checkout\scripts\install.ps1" -ProjectPath $testProject -Preview
& "$checkout\scripts\install.ps1" -ProjectPath $testProject
Get-ChildItem -LiteralPath "$testProject\.agents\skills", "$testProject\.claude\skills" -Recurse -Filter SKILL.md
Set-Location $testProject
codex
```

Users should invoke `$echo Hello, team!` in Codex and compare the response with the example above. Users can then test a multiline payload and ask a normal question to confirm that the watermark stops. After exiting Codex, users can run `claude` in the same directory and repeat the checks with `/echo`.

For a reporting test, users should start another fresh session in implementation mode and submit the following prompt, using `$progress-reporting` in Codex or `/progress-reporting` in Claude Code:

```text
$progress-reporting Implement this plan in the current disposable project:
1. Create greeting.txt with the text Hello, team!
2. Create notes.md explaining the greeting file.
3. Read both files and verify their contents.
Maintain the report as you work and record completion.
```

Users should verify that the task folder contains all four Markdown files with matching stems and the expected suffixes. The progress file should contain the configuration fields, a reference to the saved plan, a completed checklist, timestamped updates, the ending labels, and an accurate completion entry. The plan file should preserve the supplied plan, and the prompt file should preserve the initiating user message verbatim. The completion report should contain outcome, usage, timing, and improvement tables, with estimates clearly identified and timing categories accounting for elapsed time without overlap. The agent should append `AGENTS OK` to its task messages and use `unknown` for metadata it cannot observe.

The same prompt without a skill invocation tests automatic selection. A task without an existing detailed plan should produce a newly written plan before implementation. Additional checks should cover a colliding folder name, a terminal blocked outcome, unavailable usage data, and denied file writes. A collision should preserve the existing folder and carry the new numeric suffix into every filename. A blocked outcome should identify the remaining blockers in the report, and a write failure should produce an accurate explanation of missing or stale artifacts. A longer implementation task can exercise the approximate minute interval and updates after user messages while confirming that the initial prompt snapshot remains unchanged; the short greeting task will usually finish before that interval.

The automated suite checks installation behavior without calling a model or using an account. Its global-install tests use an isolated child-process home, so the suite does not install skills into the developer's real profile.

```powershell
Set-Location $checkout
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\install.Tests.ps1
```

The following commands exercise a real global installation. Users should preview first and inspect any pre-existing skill with the same name before replacing it.

```powershell
& "$checkout\scripts\install.ps1" -Scope global -Skills echo -Preview
& "$checkout\scripts\install.ps1" -Scope global -Skills echo
```

Users can launch an agent in another project without project-installed skills to check global discovery. After closing the test sessions, users can remove the disposable project with the following guarded cleanup:

```powershell
Set-Location $checkout
$resolvedTest = [IO.Path]::GetFullPath($testProject)
$temporaryRoot = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')
if ((Split-Path -Parent $resolvedTest) -ne $temporaryRoot -or
    (Split-Path -Leaf $resolvedTest) -notlike 'skill-maxx-manual-*') {
    throw 'The cleanup target is not the expected disposable project.'
}
Remove-Item -LiteralPath $resolvedTest -Recurse -Force
```

## Skill Updates and Removal

Users can update their source checkout with `git pull --ff-only` and rerun the installer with `-Replace` or `--replace`, selecting the same scope, agent, and skills. Teams that need reproducible versions can check out a reviewed tag or commit before installing. Users should preserve any local edits they need before replacement.

```powershell
.\scripts\install.ps1 -Scope global -Skills progress-reporting -Replace
```

```bash
/bin/bash scripts/install.sh --scope global --skills progress-reporting --replace
```

Users can uninstall a skill by deleting only its named folder from the appropriate destination listed above. For example, removing the global echo test means deleting `<user-home>/.agents/skills/echo` and/or `<user-home>/.claude/skills/echo`. Users should confirm those folders contain the test installation before deleting them and start a fresh session afterward. Removal does not delete reports or the source checkout.

## Skill Development and Automated Validation

Developers can add a folder under `skills/` whose name uses lowercase letters, digits, and single hyphens. Each folder must contain a `SKILL.md` that starts with the following four-line header. The folder name and `name` field must match. The installers deliberately validate this repository's simple header format without a YAML runtime; the description must be a nonempty, single-line YAML string. Developers should quote YAML-special characters when needed.

```yaml
---
name: example-skill
description: Describe the capability and the requests that should activate it.
---
```

The body contains the instructions. Developers should include supporting scripts, references, or assets only when the skill needs them and use relative links within the skill folder. Both installers copy those resources and discover new folders when the selection is `all`.

The following commands run the native test suites:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\install.Tests.ps1
```

```bash
/bin/bash tests/install.test.sh
```

GitHub Actions runs the PowerShell suite on Windows and the Bash suite on macOS. The suites cover project and global scopes, agent and skill selection, spaces in paths, invocation from another directory, identical reinstalls, replacement, preview mode, invalid inputs, destination links, resources, and preservation of unrelated files. Installation tests validate skill headers and copied content; the manual model checks above validate skill behavior.

## Cloud Product Agent Deployment

A cloud agent needs the skill files in its own runtime. A developer's global installation does not distribute those files to the product. The product's deployment should obtain a reviewed repository commit and package the selected skill folder and its resources into the application image or deployment artifact, for example at `/app/skills/progress-reporting/`. The image should record the source commit so deployments can be reproduced and rolled back.

If the product launches Codex or Claude Code, its startup or build process can use the project installer to copy the selected skills into the agent's working project. The runtime must enable the client's project skill discovery and give the agent access to that directory. The runtime's user home can differ from the build user's home, so project installation is the more explicit deployment choice.

```bash
/bin/bash /opt/skill-maxx/scripts/install.sh \
  --agent codex --scope project --skills progress-reporting \
  --project-path /workspace
```

For a custom agent loop, the product must implement discovery and loading. The application can use this sequence:

1. The application scans its packaged skill directories and reads each `SKILL.md` header with a YAML parser.
2. The application exposes each skill's name and description to the model and supports an explicit user selection or a model request to load a named skill.
3. The application reads the selected skill body and adds it to the agent's instruction context, below the product's own policies. The application resolves referenced resources relative to the selected skill folder.
4. The application makes the required tools available. Progress reporting needs a clock and a writable per-session working directory; echo needs no tools.
5. The application preserves active skill instructions across the relevant task turns and ends their scope correctly. Echo applies to one invocation; progress reporting applies to the implementation task.
6. The application persists the entire task folder from `agent-work-logs/` to its artifact store before an ephemeral worker is destroyed and provides the user with access to the progress, plan, prompt, and completion files. The application preserves any available partial artifacts if the worker stops before completion.

The product should isolate working directories between users and sessions, load only its packaged or approved skills, and keep report paths inside the session workspace. A skill file does not grant tool permissions or automatically schedule periodic execution. If the product requires exact echo output or guaranteed reporting intervals, the product should implement those guarantees in its own runtime and use the skill to describe the corresponding behavior.

A cloud smoke test should load `echo`, submit a multiline payload, compare the returned text and watermark, and verify that the next normal turn is unaffected. A reporting smoke test should run a small implementation plan, inspect all four persisted task files and the completion tables, and verify that unknown runtime metadata remains marked as unknown. Teams should run these checks against each supported model and agent runtime before releasing a new skill revision.
