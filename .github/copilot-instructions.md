# Copilot Instructions

## Feature Request Template

When the user is writing a markdown file that contains a `# Feature Request:` heading,
recognize this as a structured template and suggest completions that follow this format:

```markdown
# Feature Request: <title>

## Summary
<1-3 sentence description of what the feature does and why it matters>

## Workflow
<Numbered steps describing the user-facing workflow>

## Implementation Details
<Technical implementation broken into sub-sections with code examples where relevant>

## Considerations
<Edge cases, trade-offs, alternatives, and open questions>

<!-- # Outputs -->
<List of concrete deliverables/files produced>
```

### Section Guidelines

**Summary**: Should answer "what" and "why" concisely. Reference the user's actual tools and workflow (Neovim, mini.nvim, Copilot, Claude Code agents, etc.).

**Workflow**: Describe the step-by-step user experience. Use numbered lists. Each step should be a concrete action the user takes, not an implementation detail.

**Implementation Details**: Break into sub-headings per component. Include:
- File paths (relative to the nvim config root)
- Code snippets showing key changes
- Configuration options and their effects
- Integration points with existing systems

**Considerations**: Include:
- Edge cases and failure modes
- Alternative approaches considered
- Performance implications
- Dependencies and compatibility

**Outputs**: Uncomment the heading and list concrete files that will be created or modified.

### Context Awareness

This Neovim config (MiniMax) uses:
- `mini.nvim` ecosystem (MiniDeps, MiniSnippets, MiniCompletion, etc.)
- `zbirenbaum/copilot.lua` for GitHub Copilot
- Snippets in `after/snippets/markdown.json` (JSON format, VSCode-compatible)
- Prompt/template files written in markdown for Claude Code agents
- Leader key is Space, two-key semantic mappings

When suggesting content for feature requests, prefer solutions that integrate with the existing mini.nvim ecosystem and follow the config's established patterns.

## Prompt Templates

This config contains prompt snippets for AI agent orchestration. When the user writes
markdown files with agent-related content (orchestrator prompts, agent profiles, skill
templates), suggest completions consistent with the multi-agent patterns established
in the snippet collection:
- Orchestrator pattern: coordinator that delegates to unix-coder and code-review agents
- Agent profiles: role description, core philosophy, implementation standards
- Skill templates: name, description, purpose, variables, workflow, cookbook
