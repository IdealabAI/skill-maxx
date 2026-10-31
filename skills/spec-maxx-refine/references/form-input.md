# Clarification Form Input

The builder requires Node.js 18 or later and uses only built-in modules. The agent invokes it through the available shell tool; installing the skill does not register a separate tool or grant execution permissions.

The command accepts an input JSON file and a new output HTML path. The output directory must already exist. The builder validates the input, refuses to overwrite an existing output file, and prints the generated path. It resolves its template relative to its own installed location, so the command can run from any working directory.

```text
node "<skill-directory>/scripts/build-form.cjs" "questions.json" "clarification.html"
```

## JSON Fields

The JSON object has exactly two required fields:

- `spec` must be a nonempty string identifying the reviewed document by its path.
- `questions` must be an array of question objects. An empty array produces a form that states that no questions remain.

Each question has exactly six required fields:

- `id` must be a unique, nonempty string such as `Q1`.
- `category` must be a nonempty string naming the relevant evaluation category. The form displays the category below the issue in the same column.
- `citations` must be a nonempty string identifying the relevant line numbers, section headings or identifiers, and excerpts of up to one sentence per cited passage. For missing information, the agent identifies the section where the information belongs.
- `issue` must be a nonempty string explaining the ambiguity or conflict and its effect on implementation or testing. The agent includes a suggested correction when the document supports one. The citations appear in a separate column from this explanation.
- `question` must be a nonempty string containing the clarification question.
- `choices` must be an array of at least two distinct, nonempty answer strings.

The builder rejects unknown fields and duplicate IDs or choices. The builder adds Other automatically; the agent excludes that choice from the input.

The [example input](example-questions.json) illustrates the format. All supplied strings are treated as text. The generated HTML embeds the data and runtime, so the user only needs the HTML file. The page makes no network requests and does not persist entries after a reload.

## Form Response

Every question has an always-editable text field and an independent checkbox labeled "document manually edited". Neither control requires a selected choice. The text field remains optional, including when Other is selected.

Submit generates an instruction followed by JSON with `spec` and an `answers` array. A question is included when the user selects a choice (including Other), enters non-whitespace text, or checks the manual-edit checkbox. Questions the user has not addressed are omitted. Each included entry contains these fields:

- `id` identifies the original question.
- `answer` contains the selected predefined answer, or `null` when Other or no choice is selected.
- `text` contains the text field verbatim, including an empty string, regardless of the selected choice.
- `documentManuallyEdited` contains the checkbox's boolean value, independently of the selected choice.

The agent uses the original input to interpret each ID. Omission does not resolve a question. A manual-edit flag asks the agent to re-read the relevant document passage before proposing revisions; the flag alone does not establish that the issue is resolved. If the current document is unavailable, the agent asks for the updated passage.
