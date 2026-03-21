# Feature Request: Copilot Auto-Fill for Feature Request Templates

## Summary

Enable GitHub Copilot to automatically suggest and fill remaining sections of the
`feature_request` snippet template after the user provides a title and summary. This
turns the template from a static scaffold into an interactive drafting tool where
Copilot uses the title/summary context to generate relevant Workflow, Implementation
Details, and Considerations sections.

## Workflow

1. User opens a new markdown file (e.g., `docs/feature-requests/my-feature.md`)
2. User types `feature_request` and expands the snippet via mini.snippets
3. The snippet inserts the full template with the cursor at the title tabstop (`$1`)
4. User types the feature title and presses Tab to jump to the Summary tabstop (`$2`)
5. User writes a 1-3 sentence summary describing what and why
6. User presses Tab to move past the summary -- cursor lands in the Workflow section
7. Copilot reads the title + summary context (plus HTML comment hints embedded in the
   template) and begins suggesting numbered workflow steps
8. User accepts/modifies Copilot suggestions with `Alt+l` (accept) or `Alt+]`/`Alt+[`
   (cycle suggestions)
9. Process repeats for Implementation Details and Considerations sections
10. Even without using the snippet, if Copilot sees `# Feature Request:` followed by
    a title and summary, it recognizes the pattern from `.github/copilot-instructions.md`
    and suggests the remaining template structure

## Implementation Details

### 1. Enhanced `feature_request` Snippet (`after/snippets/markdown.json`)

Replace the current bare template with a version that includes HTML comment primers.
These comments are invisible in rendered markdown but provide Copilot with context
about what each section should contain:

```json
"Feature Request": {
  "prefix": "feature_request",
  "body": [
    "# Feature Request: ${1:Title}",
    "",
    "## Summary",
    "",
    "${2:Brief description of the feature and why it matters.}",
    "",
    "## Workflow",
    "<!-- Describe the step-by-step user experience as numbered actions -->",
    "",
    "${3:1. }",
    "",
    "## Implementation Details",
    "<!-- Technical breakdown: file paths, code changes, config, integration points -->",
    "",
    "${4:### }",
    "",
    "## Considerations",
    "<!-- Edge cases, trade-offs, alternatives, dependencies, open questions -->",
    "",
    "${5:- }",
    "",
    "<!-- # Outputs -->",
    "<!-- List concrete deliverable files -->",
    "$0"
  ],
  "description": "Feature request template with Copilot context hints"
}
```

Key changes from the original:
- **Tabstops** (`$1`-`$5`, `$0`): Guide the user through each section sequentially.
  After filling title and summary, Tab jumps directly into each section body.
- **HTML comment primers**: Each section header is followed by an HTML comment that
  describes what content belongs there. Copilot reads these as context for generation.
- **Seed characters**: `$3` starts with `1. `, `$4` starts with `### `, `$5` starts
  with `- `. These seed the first line of each section to prime Copilot's pattern
  recognition for numbered lists, sub-headings, and bullet points respectively.

### 2. Copilot Instructions File (`.github/copilot-instructions.md`)

Create `.github/copilot-instructions.md` at the config root. GitHub Copilot
automatically reads this file (when present in a repository) to understand
project-specific patterns and conventions.

The instructions file teaches Copilot:
- The feature request template structure and section purposes
- What content belongs in each section (Summary, Workflow, Implementation, etc.)
- Context about the MiniMax config ecosystem (mini.nvim, copilot.lua, etc.)
- Prompt/template patterns used for Claude Code agent orchestration

This works at the repository level -- any markdown file opened within the nvim config
directory benefits from these instructions.

### 3. No Plugin Changes Required

The current Copilot configuration in `plugin/40_plugins.lua` already has:
- `auto_trigger = true` -- suggestions appear automatically
- `markdown = true` in filetypes -- Copilot is active in markdown files
- Keybindings for accept (`Alt+l`), cycle (`Alt+]`/`Alt+[`), dismiss (`Ctrl+]`)

No changes to the Copilot plugin setup are needed.

### 4. How the Pieces Work Together

```
User types "feature_request" + expands snippet
         |
         v
mini.snippets inserts template with:
  - Tabstops for sequential filling
  - HTML comment primers per section
         |
         v
User fills Title ($1) and Summary ($2)
         |
         v
Tab to Workflow section ($3: "1. ")
         |
         v
Copilot sees:
  1. Title + Summary context (what the feature is)
  2. HTML comment primer ("step-by-step user experience")
  3. Seed character "1. " (numbered list pattern)
  4. .github/copilot-instructions.md (template conventions)
         |
         v
Copilot suggests relevant workflow steps
         |
         v
User accepts/modifies, moves to next section
```

## Considerations

- **Copilot suggestion quality depends on context length**: The more detailed the
  title and summary, the better Copilot's suggestions for downstream sections.
  A one-word title produces generic output; a descriptive title with technical
  terms produces targeted suggestions.

- **HTML comments as primers vs. placeholder text**: HTML comments are preferred
  because they are invisible in rendered markdown but still visible to Copilot.
  Placeholder text (like the tabstop defaults) would need to be deleted before
  typing, which adds friction.

- **Tabstop defaults vs. empty tabstops**: The snippet uses short defaults
  (`1. `, `### `, `- `) rather than descriptive placeholders. This is intentional:
  descriptive placeholders get replaced when the user types, losing the Copilot
  primer. Short seeds remain useful even if the user starts typing immediately.

- **`.github/copilot-instructions.md` scope**: This file affects all Copilot
  suggestions within the repository, not just feature requests. The instructions
  are written to be helpful for all markdown files in the config, including agent
  prompts and skill templates.

- **No runtime overhead**: This approach uses zero Lua code changes, zero new
  plugins, and zero autocommands. It works entirely through static files that
  Copilot and mini.snippets already know how to consume.

- **Alternative: `copilot.lua` panel mode**: The Copilot panel (`:Copilot panel`
  or `Alt+Enter`) shows multiple suggestions at once. Users can open the panel
  after entering the summary to see several possible completions for the entire
  remaining template. This is complementary to inline suggestions.

- **Alternative: Custom Lua function**: A more complex approach would be a Lua
  function that programmatically sets `vim.b.copilot_suggestion_auto_trigger` and
  injects context via the buffer. This was rejected in favor of the simpler
  static-file approach, which achieves 80% of the benefit with 0% of the
  maintenance cost.

# Outputs

- `after/snippets/markdown.json` -- Updated `feature_request` snippet with tabstops
  and HTML comment Copilot primers
- `.github/copilot-instructions.md` -- Repository-level Copilot instructions teaching
  the template pattern and MiniMax conventions
- `docs/feature-requests/copilot-template-autofill.md` -- This document (the feature
  request itself, written in its own template format)
