# Markdown Snippet Usage Guide

Quick reference for using the markdown snippets in Neovim.

## Available Snippets

### `orch` - Orchestrator Prompt
**Use when:** Setting up multi-agent coordination workflows

**Trigger:** Type `orch` in a markdown file and expand

**Content:** System prompt for orchestrating multiple AI agents (unix-coder, code-reviewer) to work in parallel tracks without implementing code directly.

### `ddog` - Datadog SME Profile
**Use when:** Working on Datadog observability implementations

**Trigger:** Type `ddog` in a markdown file and expand

**Content:** Comprehensive profile for Datadog subject matter expert including Unix philosophy, Google Golden Signals, implementation standards, and output format for creating developer documentation.

### `orggen` - Org Generator Prompt
**Use when:** Creating Datadog terraform organization setup tools

**Trigger:** Type `orggen` in a markdown file and expand

**Content:** Prompt for generating a plugin that creates base Datadog monitoring profiles using Terraform, including client questionnaires for POC engagements.

### `unix` - Unix Coder Profile
**Use when:** Defining a systems programming agent profile

**Trigger:** Type `unix` in a markdown file and expand

**Content:** Expert systems programmer profile emphasizing Unix philosophy, clean code principles (KISS, DRY, YAGNI), and implementation standards.

### `sre` - SRE Profile
**Use when:** Setting up site reliability engineering context

**Trigger:** Type `sre` in a markdown file and expand

**Content:** Senior SRE profile with expertise in observability, IaC, cloud platforms, and Kubernetes. Includes Google Golden Signals framework.

## How to Use Snippets in Neovim

1. **Open a markdown file** (`.md` extension)
2. **Type the snippet prefix** (e.g., `orch`)
3. **Trigger snippet expansion** (method depends on your snippet plugin):
   - With mini.snippets: completion menu or dedicated keybinding
   - The snippet body will be inserted at cursor position

## Testing Snippets

To verify all snippets are working correctly:

```bash
cd /home/n0ko/.config/nvim/tests
./run_all_tests.sh
```

This runs:
- JSON structure validation
- Field presence and type checking
- Content validation
- Neovim loading tests

## Example Workflow

1. Create a new markdown file for agent instructions:
   ```bash
   nvim agent_profile.md
   ```

2. Type snippet prefix and expand:
   ```
   # Setting up Datadog monitoring

   ddog<expand>
   ```

3. The full Datadog SME profile is inserted, ready to use as system instructions.

## Directory Structure

```
/home/n0ko/.config/nvim/
├── after/
│   └── snippets/
│       └── markdown.json          # Snippet definitions
└── tests/
    ├── test_markdown_snippets.py  # Python validation tests
    ├── test_nvim_load.sh          # Neovim loading tests
    ├── run_all_tests.sh           # Test runner
    ├── README.md                  # Testing documentation
    └── USAGE.md                   # This file
```

## Notes

- All snippets are available only in markdown files (`.md`)
- Snippets are loaded from `/home/n0ko/.config/nvim/after/snippets/markdown.json`
- The `after/` directory ensures snippets load after main config
- Each snippet includes a descriptive comment for completion menus
