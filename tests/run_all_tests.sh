#!/bin/bash
#
# Run all snippet tests
# Executes both Python validation and Neovim loading tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXIT_CODE=0

echo "=========================================="
echo "Running Snippet Test Suite"
echo "=========================================="
echo

# Run Python validation tests
echo ">>> Running Python validation tests..."
echo
if python3 "$SCRIPT_DIR/test_markdown_snippets.py"; then
    echo
    echo "✓ Python validation tests passed"
else
    echo
    echo "✗ Python validation tests failed"
    EXIT_CODE=1
fi

echo
echo "=========================================="
echo

# Run Neovim loading tests
echo ">>> Running Neovim loading tests..."
echo
if bash "$SCRIPT_DIR/test_nvim_load.sh"; then
    echo "✓ Neovim loading tests passed"
else
    echo "✗ Neovim loading tests failed"
    EXIT_CODE=1
fi

echo
echo "=========================================="
echo "Test Suite Complete"
echo "=========================================="
echo

if [[ $EXIT_CODE -eq 0 ]]; then
    echo "✓ All tests passed successfully!"
else
    echo "✗ Some tests failed (exit code: $EXIT_CODE)"
fi

exit $EXIT_CODE
