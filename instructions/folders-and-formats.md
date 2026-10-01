Make the following changes to the progress-report skill:

- Instead of making a single file in a reports subfolder, create a folder that will contain multiple files:
  - Locate the folder in [working directory]/agent-work-logs/
  - Choose the folder name the same way the current file's name is being generated.
  - Save all progress to a file within that folder whose name matches the folder's name, omitting the timestamp, and appending a "-progress" suffix before the file extension.
  - When the work begins, create a .md file alongside the progress file with the same name but different suffix of "-implementation-plan" and copy in the detailed plan that is being implemented if one exists, or write one if one doesn't yet exist.
  - When the work begins, also create a .md file with the suffix "-user-prompt" and copy in the most recent text the user sent to the session to prompt the agent.
  - When the work is complete, create a file with the suffix "-report" and add tabular content stating the following:
    - Whether the work was completed successfully, and if not, name the problems that occurred.
    - Estimate total token usage.
    - Print total time spent on the task, and give best estimate for the breakdown in a table format showing what the time was spent on, making it clear how much time was spent during agent inferrence vs. tool use, or other categories.
    - List suggestions for what could be changed about the prompt, the tools, or the models used that would have made the same job complete faster without significant compromise to quality and/or what would have made the job complete with higher quality without significant compromise to speed.
    - Name the greatest source of token use, if one is obvious.
