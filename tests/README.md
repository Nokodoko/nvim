# Snippet Tests

Test suite for validating Neovim snippet files, specifically the markdown snippets.

## Test Files

### `test_markdown_snippets.py`

Python-based validation script that performs comprehensive JSON and content validation:

- **JSON Structure**: Validates the file is valid JSON with correct structure
- **Required Fields**: Ensures each snippet has `prefix`, `body`, and `description` fields
- **Field Types**: Validates field types (string, array of strings)
- **Content Validation**: Checks body content is non-empty and meaningful
- **Expected Snippets**: Verifies all required snippets exist with correct prefixes

**Usage:**
```bash
python3 test_markdown_snippets.py
```

### `test_nvim_load.sh`

Shell script that tests Neovim integration:

- **File Existence**: Verifies snippet file exists and is readable
- **JSON Validation**: Uses `jq` to validate JSON syntax
- **Neovim Loading**: Tests that Neovim can start with snippets loaded
- **Structure Validation**: Uses `jq` to verify snippet structure

**Usage:**
```bash
bash test_nvim_load.sh
```

### `run_all_tests.sh`

Test runner that executes both test suites in sequence.

**Usage:**
```bash
bash run_all_tests.sh
```

## Tested Snippets

The test suite validates the following markdown snippets:

| Prefix   | Snippet Name           | Description                                      |
|----------|------------------------|--------------------------------------------------|
| `orch`   | Orchestrator Prompt    | Multi-agent coordination system prompt           |
| `ddog`   | Datadog SME Profile    | Datadog observability tooling expert profile     |
| `orggen` | Org Generator Prompt   | Datadog terraform org generator plugin prompt    |
| `unix`   | Unix Coder Profile     | Unix philosophy systems programming profile      |
| `sre`    | SRE Profile            | Site reliability engineering profile             |

## Requirements

- Python 3.6+
- Neovim (nvim)
- jq (JSON processor)
- bash

## Running Tests

Run all tests:
```bash
cd /home/n0ko/.config/nvim/tests
./run_all_tests.sh
```

Run individual test suites:
```bash
# Python validation only
python3 test_markdown_snippets.py

# Neovim loading only
bash test_nvim_load.sh
```

## Exit Codes

- `0`: All tests passed
- `1`: Tests failed
- `2`: Unexpected error (Python tests only)

## Test Output

Both test suites provide detailed output showing:
- Which tests are running
- Pass/fail status for each test
- Summary of all snippets
- Final test results

Example output:
```
✓ All tests passed!
  Total snippets: 5
  Total tests: 10
```
