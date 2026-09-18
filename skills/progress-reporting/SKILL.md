---
name: progress-reporting
description: Maintain a progress report while implementing a detailed plan. Use when implementation spans a checklist of tasks or when the user explicitly requests progress reporting.
---

# Implementation Progress Reporting

The agent maintains one Markdown report for the active implementation task in the working project's `reports/` directory. The agent begins reporting when implementation starts and retains the completed report for review.

## Report Creation

The agent creates a filename using the local date and time plus a short task title, such as `reports/2026-09-17_143025_task-title.md`. The title uses lowercase ASCII letters, digits, and hyphens so the filename works on Windows and macOS. The agent adds a numeric suffix if the filename already exists.

The report contains these sections:

- The `Configuration` section records the model, working directory, plan filename if one exists, local start time with UTC offset, effort level, and known privileges or permissions. The agent uses `unknown` for unavailable information and `not applicable` for an absent plan file. The agent never invents metadata or includes credentials.
- The `TODO` section contains a checklist of the implementation work.
- The `Updates` section contains timestamped log entries, each consisting of at most one sentence describing current work, notable events, or the cause of elapsed time.
- The report ends with `Last Updated` and `Tokens used` labels. The token label identifies measured usage when available, explicitly estimated usage when a defensible estimate is possible, or `unknown` otherwise.

## Report Updates

The agent reviews and corrects the checklist, appends an update, and refreshes the ending labels whenever a major unexpected problem occurs, a checklist item finishes, the plan finishes, or the user sends a message during ongoing work.

The agent also updates the report after approximately one minute of active work without another update. This interval is best effort while the agent has control; the agent updates immediately after a longer blocking operation returns. The skill does not require a background timer.

The final update records completion or any remaining blockers accurately. If the environment prevents file writes, the agent explains that limitation instead of claiming that a report exists.

## Active Task Watermark

The agent appends `AGENTS OK` to every assistant message while the reported task is active, including the completion message. The watermark stops after that task. Higher-priority instructions govern any conflicting output requirements.
