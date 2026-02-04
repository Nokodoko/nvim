#!/usr/bin/env python3
"""
Test suite for markdown snippet validation.

Validates JSON structure, required fields, and snippet content
for /home/n0ko/.config/nvim/after/snippets/markdown.json
"""

import json
import sys
from pathlib import Path
from typing import Any, Dict, List, Tuple


SNIPPET_FILE = Path.home() / ".config/nvim/after/snippets/markdown.json"
REQUIRED_SNIPPETS = {
    "orch": "Orchestrator Prompt",
    "ddog": "Datadog SME Profile",
    "orggen": "Org Generator Prompt",
    "unix": "Unix Coder Profile",
    "sre": "SRE Profile",
}


def load_snippets() -> Dict[str, Any]:
    """Load and parse the snippet JSON file."""
    try:
        with open(SNIPPET_FILE, 'r') as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"ERROR: Snippet file not found: {SNIPPET_FILE}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON in {SNIPPET_FILE}: {e}")
        sys.exit(1)


def validate_json_structure(snippets: Dict[str, Any]) -> List[str]:
    """Validate the overall JSON structure."""
    errors = []

    if not isinstance(snippets, dict):
        errors.append("Root element must be a dictionary")
        return errors

    if len(snippets) == 0:
        errors.append("Snippet file is empty")

    return errors


def validate_snippet_fields(snippet: Dict[str, Any]) -> List[str]:
    """Validate required fields for a single snippet."""
    errors = []
    required_fields = ["prefix", "body", "description"]

    # Check required fields exist
    for field in required_fields:
        if field not in snippet:
            errors.append(f"Missing required field '{field}'")

    # Validate prefix
    if "prefix" in snippet:
        if not isinstance(snippet["prefix"], str):
            errors.append("Field 'prefix' must be a string")
        elif not snippet["prefix"].strip():
            errors.append("Field 'prefix' cannot be empty")

    # Validate body
    if "body" in snippet:
        if isinstance(snippet["body"], list):
            if len(snippet["body"]) == 0:
                errors.append("Field 'body' array is empty")
            # Check all elements are strings
            for i, line in enumerate(snippet["body"]):
                if not isinstance(line, str):
                    errors.append(f"Field 'body' line {i} must be a string")
        elif isinstance(snippet["body"], str):
            if not snippet["body"].strip():
                errors.append("Field 'body' string is empty")
        else:
            errors.append("Field 'body' must be a string or array of strings")

    # Validate description
    if "description" in snippet:
        if not isinstance(snippet["description"], str):
            errors.append("Field 'description' must be a string")
        elif not snippet["description"].strip():
            errors.append("Field 'description' cannot be empty")

    return errors


def validate_expected_snippets(snippets: Dict[str, Any]) -> List[str]:
    """Verify all expected snippets exist with correct prefixes."""
    errors = []
    found_prefixes = {}

    # Build prefix -> name mapping
    for name, snippet in snippets.items():
        if "prefix" in snippet:
            prefix = snippet["prefix"]
            found_prefixes[prefix] = name

    # Check each expected snippet
    for expected_prefix, expected_name in REQUIRED_SNIPPETS.items():
        if expected_prefix not in found_prefixes:
            errors.append(f"Missing expected snippet with prefix '{expected_prefix}'")
        elif found_prefixes[expected_prefix] != expected_name:
            errors.append(
                f"Snippet with prefix '{expected_prefix}' has name "
                f"'{found_prefixes[expected_prefix]}', expected '{expected_name}'"
            )

    return errors


def validate_body_content(snippet: Dict[str, Any]) -> List[str]:
    """Validate snippet body has meaningful content."""
    errors = []

    if "body" not in snippet:
        return errors

    body = snippet["body"]

    # Convert to list if string
    if isinstance(body, str):
        lines = [body]
    else:
        lines = body

    # Check for non-empty content
    non_empty_lines = [line for line in lines if line.strip()]
    if len(non_empty_lines) == 0:
        errors.append("Body contains no non-empty lines")

    # Minimum content length check
    total_content = "".join(non_empty_lines)
    if len(total_content) < 10:
        errors.append(f"Body content is too short ({len(total_content)} chars)")

    return errors


def run_tests() -> Tuple[int, int]:
    """Run all validation tests and return (passed, failed) counts."""
    print(f"Testing snippet file: {SNIPPET_FILE}\n")

    # Load snippets
    print("[1/5] Loading snippet file...")
    snippets = load_snippets()
    print(f"  ✓ Loaded {len(snippets)} snippets\n")

    # Test JSON structure
    print("[2/5] Validating JSON structure...")
    errors = validate_json_structure(snippets)
    if errors:
        for error in errors:
            print(f"  ✗ {error}")
        return 0, len(errors)
    print("  ✓ JSON structure valid\n")

    # Test expected snippets
    print("[3/5] Validating expected snippets...")
    errors = validate_expected_snippets(snippets)
    if errors:
        for error in errors:
            print(f"  ✗ {error}")
        return 0, len(errors)
    print(f"  ✓ All {len(REQUIRED_SNIPPETS)} expected snippets found\n")

    # Test individual snippets
    print("[4/5] Validating snippet fields...")
    total_errors = 0
    for name, snippet in snippets.items():
        snippet_errors = validate_snippet_fields(snippet)
        if snippet_errors:
            print(f"  Snippet '{name}':")
            for error in snippet_errors:
                print(f"    ✗ {error}")
            total_errors += len(snippet_errors)

    if total_errors == 0:
        print(f"  ✓ All snippet fields valid\n")
    else:
        print()

    # Test body content
    print("[5/5] Validating snippet content...")
    content_errors = 0
    for name, snippet in snippets.items():
        body_errors = validate_body_content(snippet)
        if body_errors:
            print(f"  Snippet '{name}':")
            for error in body_errors:
                print(f"    ✗ {error}")
            content_errors += len(body_errors)

    if content_errors == 0:
        print(f"  ✓ All snippet content valid\n")
    else:
        print()

    total_failed = total_errors + content_errors
    return len(snippets) * 2, total_failed  # 2 tests per snippet


def print_snippet_summary(snippets: Dict[str, Any]):
    """Print summary of all snippets."""
    print("=" * 60)
    print("SNIPPET SUMMARY")
    print("=" * 60)

    for name, snippet in snippets.items():
        prefix = snippet.get("prefix", "N/A")
        description = snippet.get("description", "N/A")

        # Count body lines
        body = snippet.get("body", [])
        if isinstance(body, str):
            line_count = 1
        else:
            line_count = len(body)

        print(f"\nSnippet: {name}")
        print(f"  Prefix:      {prefix}")
        print(f"  Description: {description}")
        print(f"  Body lines:  {line_count}")


def main():
    """Main test runner."""
    try:
        snippets = load_snippets()
        passed, failed = run_tests()

        # Print summary
        print_snippet_summary(snippets)

        # Print results
        print("\n" + "=" * 60)
        print("TEST RESULTS")
        print("=" * 60)

        if failed == 0:
            print(f"\n✓ All tests passed!")
            print(f"  Total snippets: {len(snippets)}")
            print(f"  Total tests: {passed}")
            return 0
        else:
            print(f"\n✗ Some tests failed")
            print(f"  Tests passed: {passed}")
            print(f"  Tests failed: {failed}")
            return 1

    except Exception as e:
        print(f"\nUnexpected error: {e}")
        import traceback
        traceback.print_exc()
        return 2


if __name__ == "__main__":
    sys.exit(main())
