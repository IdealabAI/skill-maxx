---
name: spec-maxx-refine
description: Analyze a user-supplied, human-written specification for clarity, completeness, and ambiguity. Use when the user requests a review or refinement of an existing spec document.
---

The version of this skill is 0.1.7. Mention the name and version of this skill in your final response to the user the first time it is invoked in a session.

Your objective is to review a user-supplied specification document for completeness, ambiguity, and testability. The user's prompt must include at least one source spec document or portions thereof; if it doesn't, halt the review, and respond to the user asking them to provide the document(s).

## Evaluation Rubric

Your review should adhere to the following:

- Review the candidate specification line-by-line, section-by-section, and as a whole.
- Separately consider each of the categories listed in Appendix A of this skill.
- Evaluate whether the spec is fully-constrained: it is fully-constrained if it would be implemented to have the same observable behavior and performance characteristics by any sufficiently-skilled human or agent developer.
- Evaluate whether the spec is testable: it is testable if a candidate implementation can be tested against all statements in the spec for correctness.
- Evaluate whether the spec is concise: it must contain only relevant information, and must not repeat the same information redundantly.

## Response Questions and Clarifications

Your response should be a numbered list of issues identified by your review. Each reported issue must include the following information:

- A statement of the issue that includes the reason why it is an issue.
- Citations to the line number, section heading (or section identifier), and a quoted snippet of 3-5 words indicating the location(s) in the spec referenced by your issue.
- A question for the user which would resolve the issue, if answered in a revision to the spec document.
- If appropriate, 2-4 multiple choice options for the most likely answers to the above question, but only in cases where you can identify such likely options.
- If a user's intent was clear, but the spec itself does not clearly articulate that somehow (e.g. mis-spelling, inconsistent terminology), suggest a revision which includes the excerpt before and after your proposed revision.

After assembling a list of issues for your response, consider each issue, and omit any issues which are deemed frivolous, trivial, or illegitimate, according to the following criteria. The issue should be omitted if any of the following are true:

- The issue is trivial: it does not meaningfully impact the behavior of an app developed from the spec.
- The issue's resolution would require adding unnecessary or redundant information to the spec.
- The issue hypothesizes a feature, characteristic, or exception merely because it is not explicitly prohibited by the spec.

The complete list of reported issues should include the minimal set such that if each was sufficiently addressed in a future revision of the spec, the spec could then be used as a basis for generating a complete set of acceptance tests for the application. If there are no such issues, then your report should include no issues, and your response should say that there are no issues.&#x20;

## Appendix A: Categories for evaluation

- Functional Scope & Behavior
  - Core user goals & success criteria
  - Explicit out-of-scope declarations
  - User roles / personas differentiation
- Domain & Data Model
  - Entities, attributes, relationships
  - Identity & uniqueness rules
  - Lifecycle/state transitions
  - Data volume / scale assumptions
- Interaction & UX Flow
  - Critical user journeys / sequences
  - Error/empty/loading states
  - Accessibility or localization notes
- Non-Functional Quality Attributes
  - Performance (latency, throughput targets)
  - Scalability (horizontal/vertical, limits)
  - Reliability & availability (uptime, recovery expectations)
  - Observability (logging, metrics, tracing signals)
  - Security & privacy (authN/Z, data protection, threat assumptions)
  - Compliance / regulatory constraints (if any)
- Integration & External Dependencies
  - External services/APIs and failure modes
  - Data import/export formats
  - Protocol/versioning assumptions
- Edge Cases & Failure Handling
  - Negative scenarios
  - Rate limiting / throttling
  - Conflict resolution (e.g., concurrent edits)
- Constraints & Tradeoffs
  - Technical constraints (language, storage, hosting)
  - Explicit tradeoffs or rejected alternatives
- Terminology & Consistency
  - Canonical glossary terms
  - Avoided synonyms / deprecated terms
- Completion Signals
  - Acceptance criteria testability
  - Measurable Definition of Done style indicators
- Misc / Placeholders
  - TODO markers / unresolved decisions
  - Ambiguous adjectives ("robust", "intuitive") lacking quantification
