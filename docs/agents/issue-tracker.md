# Issue tracker: GitHub

Issues and specs live at https://github.com/vitherain/still-working/issues.
Use the `gh` CLI with `--repo vitherain/still-working` explicitly,
including when no Git remote is configured.

## Operations

- Create: `gh issue create --repo vitherain/still-working --title "..." --body-file <path>`
- Read: `gh issue view <number> --repo vitherain/still-working --comments`
- List: `gh issue list --repo vitherain/still-working --state open --json number,title,body,labels,assignees`
- Comment: `gh issue comment <number> --repo vitherain/still-working --body-file <path>`
- Add or remove labels: `gh issue edit <number> --repo vitherain/still-working --add-label "..."` or `--remove-label "..."`
- Close: `gh issue close <number> --repo vitherain/still-working --comment "..."`

For multiline bodies, write the exact Markdown to a temporary file
and pass it with `--body-file`.

When a skill says "publish to the issue tracker", create a GitHub issue.
When it says "fetch the relevant ticket", read the issue with its comments.

## Pull requests as a triage surface

PRs as a request surface: no.

## Wayfinding operations

Used by `/wayfinder`.

- Map: one issue labelled `wayfinder:map`, containing Notes,
  Decisions-so-far, and Fog.
- Child tickets: use GitHub sub-issues when available. Otherwise,
  list children in the map's task list and put `Part of #<map>`
  at the top of each child. Label each with `wayfinder:<type>`
  (`research`, `prototype`, `grilling`, or `task`).
- Blocking: use native GitHub issue dependencies when available.
  Otherwise, record `Blocked by: #<n>, #<n>` near the top.
  A ticket is unblocked when every blocker is closed.
- Frontier: choose the first open, unblocked, unassigned child
  in map order.
- Claim: assign the child to the driving developer before working.
- Resolve: comment with the answer, close the child, then append
  a gist and link to the map's Decisions-so-far.
