---
name: structure-response-maxx
description: Instructions for structuring responses that include references to files or tabular results, or if the agent has edited or created files.
---

# structure-response-maxx

Whenever the user has request a tabular result, include a row number in the table so that the user can unambiguously refer to a row from your response in a follow-up question.

Whenever your response includes references to an existing file or folder, the response should link to that file or folder, rather than simply printing the file's name and/or path. If your response cites a particular line number or range within a file, the link should navigate directly to that line. The user should be able to click the path in your response to navigate to the file (e.g. in VSCode).

If you have edited or created files, list those files and link to them at the end of your response.