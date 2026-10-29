# Clarification Form Input

The builder requires Node.js 18 or later and uses only built-in modules. The agent invokes it through the available shell tool; installing the skill does not register a separate tool or grant execution permissions.

The command accepts an input JSON file and a new output HTML path. The output directory must already exist. The builder validates the input, refuses to overwrite an existing output file, and prints the generated path. It resolves its template relative to its own installed location, so the command can run from any working directory.

```text
node "<skill-directory>/scripts/build-form.cjs" "questions.json" "clarification.html"
```

## JSON Fields

The JSON object has exactly three required fields:

- `schemaVersion` must be the number `1`.
- `spec` must be a nonempty string identifying the reviewed document by its path.
- `questions` must be an array of question objects. An empty array produces a form that states that no questions remain.

Each question has exactly five required fields:

- `id` must be a unique, stable, nonempty string such as `Q1`.
- `category` must be a nonempty string naming the relevant evaluation category.
- `passage` must be a nonempty string quoting or locating the relevant passage. For missing information, the agent identifies the section where the information belongs.
- `question` must be a nonempty string containing the clarification question.
- `choices` must be an array of at least two distinct, nonempty answer strings.

The builder rejects unknown fields and duplicate IDs or choices. The builder adds Other and Defer decision automatically; the agent excludes those choices from the input.

The [example input](example-questions.json) illustrates the format. All supplied strings are treated as text. The generated HTML embeds the data and runtime, so the user only needs the HTML file. The page makes no network requests and does not persist selections after a reload. Submit generates an instruction followed by JSON containing the spec identity, question IDs, question text, answer text, and Answered, Deferred, or Unanswered statuses.
