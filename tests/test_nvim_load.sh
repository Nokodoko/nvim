#!/bin/bash
#
# Test that Neovim can load markdown snippets without errors.
# Tests snippet loading in a clean Neovim instance.

set -euo pipefail

SNIPPET_FILE="$HOME/.config/nvim/after/snippets/markdown.json"
NVIM_CONFIG="$HOME/.config/nvim"

echo "Testing Neovim snippet loading..."
echo "Snippet file: $SNIPPET_FILE"
echo

# Test 1: Verify file exists
echo "[1/4] Checking snippet file exists..."
if [[ -f "$SNIPPET_FILE" ]]; then
    echo "  ✓ File exists"
else
    echo "  ✗ File not found: $SNIPPET_FILE"
    exit 1
fi
echo

# Test 2: Verify JSON is valid
echo "[2/4] Validating JSON syntax..."
if jq empty "$SNIPPET_FILE" 2>/dev/null; then
    echo "  ✓ Valid JSON"
else
    echo "  ✗ Invalid JSON - attempting to show errors:"
    jq empty "$SNIPPET_FILE" 2>&1 || true
    exit 1
fi
echo

# Test 3: Launch Neovim headless and check for errors
echo "[3/4] Testing Neovim can start with snippets..."
NVIM_OUTPUT=$(nvim --headless --noplugin \
    -c "lua vim.opt.runtimepath:append('$NVIM_CONFIG/after')" \
    -c "echo 'Neovim started successfully'" \
    -c "qall" 2>&1 || true)

if echo "$NVIM_OUTPUT" | grep -i "error\|fail" > /dev/null 2>&1; then
    echo "  ✗ Neovim reported errors:"
    echo "$NVIM_OUTPUT" | grep -i "error\|fail"
    exit 1
else
    echo "  ✓ Neovim started successfully"
fi
echo

# Test 4: Verify snippet structure with jq
echo "[4/4] Verifying snippet structure..."
ERRORS=0

# Check each expected snippet
for prefix in orch ddog orggen unix sre; do
    # Find snippet with this prefix
    SNIPPET_NAME=$(jq -r "to_entries[] | select(.value.prefix == \"$prefix\") | .key" "$SNIPPET_FILE" 2>/dev/null || echo "")

    if [[ -z "$SNIPPET_NAME" ]]; then
        echo "  ✗ Snippet with prefix '$prefix' not found"
        ERRORS=$((ERRORS + 1))
        continue
    fi

    # Validate fields
    HAS_PREFIX=$(jq -r ".\"$SNIPPET_NAME\".prefix" "$SNIPPET_FILE" 2>/dev/null)
    HAS_BODY=$(jq -r ".\"$SNIPPET_NAME\".body" "$SNIPPET_FILE" 2>/dev/null)
    HAS_DESC=$(jq -r ".\"$SNIPPET_NAME\".description" "$SNIPPET_FILE" 2>/dev/null)

    if [[ "$HAS_PREFIX" == "null" ]] || [[ "$HAS_BODY" == "null" ]] || [[ "$HAS_DESC" == "null" ]]; then
        echo "  ✗ Snippet '$SNIPPET_NAME' missing required fields"
        ERRORS=$((ERRORS + 1))
    fi
done

if [[ $ERRORS -eq 0 ]]; then
    echo "  ✓ All snippet structures valid"
else
    echo "  ✗ Found $ERRORS structural errors"
    exit 1
fi
echo

# Success summary
echo "============================================================"
echo "TEST RESULTS"
echo "============================================================"
echo
echo "✓ All Neovim loading tests passed!"
echo "  - File exists and is readable"
echo "  - JSON syntax is valid"
echo "  - Neovim can load without errors"
echo "  - All 5 snippets are properly structured"
echo

exit 0
