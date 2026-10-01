---
name: progress-reporting
description: Maintain a progress report while implementing a detailed plan. Use when implementation spans a checklist of tasks or when the user explicitly requests progress reporting.
---

# Implementation Progress Reporting

The agent maintains a task folder containing Markdown progress, plan, prompt, and completion files in the working directory's `agent-work-logs/` directory. The agent begins reporting when implementation starts and retains the entire folder for review. Existing reports remain in place.

## Task Folder Creation

The agent creates a folder using the local date and time plus a short task title, such as `agent-work-logs/2026-09-17_143025_task-title/`. The title uses lowercase ASCII letters, digits, and hyphens so the name works on Windows and macOS. If the folder already exists, the agent adds an unused numeric suffix, such as `2026-09-17_143025_task-title-2`, without overwriting existing artifacts.

The filename stem matches the folder name with only the date and time prefix removed. For example, `2026-09-17_143025_task-title-2` uses the stem `task-title-2`. All four files use the `.md` extension.

At implementation start, the agent creates these three files in the task folder:

- The `<stem>-progress.md` file contains all ongoing progress updates.
- The `<stem>-implementation-plan.md` file contains a copy of the detailed plan being implemented. If no detailed plan exists, the agent writes one before implementation begins.
- The `<stem>-user-prompt.md` file contains a verbatim copy of the latest user message that prompted implementation. Later messages trigger progress updates without replacing this initial snapshot.

At completion or a terminal blocked outcome, the agent creates `<stem>-report.md` in the same folder.

## Progress File Contents

The progress file contains these sections:

- The `Configuration` section records the model, working directory, saved implementation-plan filename, local start time with UTC offset, effort level, and known privileges or permissions. The agent uses `unknown` for unavailable information. The agent never invents metadata or includes credentials in configuration information.
- The `TODO` section contains a checklist of the implementation work.
- The `Updates` section contains timestamped log entries, each consisting of at most one sentence describing current work, notable events, or the cause of elapsed time.
- The progress file ends with `Last Updated` and `Tokens used` labels. The token label identifies measured usage when available, explicitly estimated usage when a defensible estimate is possible, or `unknown` otherwise.

## Progress File Updates

The agent reviews and corrects the checklist, appends an update, and refreshes the ending labels whenever a major unexpected problem occurs, a checklist item finishes, the plan finishes, or the user sends a message during ongoing work.

The agent also updates the progress file after approximately one minute of active work without another update. This interval is best effort while the agent has control; the agent updates immediately after a longer blocking operation returns. The skill does not require a background timer.

The final update records completion or any remaining blockers accurately. If the environment prevents file writes, the agent explains which artifacts could not be created or updated instead of claiming that they exist.

## Completion Report Contents

The agent records the end time and writes Markdown tables in `<stem>-report.md` covering the following information:

- The outcome table states whether the work completed successfully and names any problems or remaining blockers.
- The usage table records total task token usage and the greatest source of token consumption when one is identifiable. The agent uses measured totals when available, a defensible estimate otherwise, and `unknown` when evidence is insufficient. Estimates include their basis and uncertainty.
- The timing table records the start time, end time, and total elapsed time. A breakdown table gives durations for agent inference, tool use, waiting, and other applicable activities, with a brief description of the work in each category. The agent distinguishes measured durations from estimates and explains uncertainty. The categories partition elapsed time without double-counting overlapping activities; time that cannot be attributed is recorded as unclassified. Tool execution is counted once even when tools run concurrently, and inference time is an estimate unless the runtime measures it.
- The improvement table lists specific changes to the prompt, tools, or models that could improve speed without significantly reducing quality, or improve quality without significantly reducing speed. Each suggestion identifies its expected benefit and relevant tradeoff. If the task provides no evidence for a useful suggestion or a greatest token source, the agent states that limitation.

## Active Task Watermark

The agent appends `PROGRESS V2` to every assistant message while the reported task is active, including the completion message. The watermark stops after that task. Higher-priority instructions govern any conflicting output requirements.
