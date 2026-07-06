#!/usr/bin/env bash
# Shared headless test loop for run_tests.sh and run_tests_extended.sh.
set -euo pipefail

run_godot_tests() {
	local root="$1"
	shift
	local failed=0
	for t in "$@"; do
		echo "==> $t"
		local out
		set +e
		out=$("$GODOT" --path "$root" --headless --script "res://tests/${t}.gd" 2>&1 | sed -E 's/\x1b\[[0-9;]*m//g')
		set -e
		local tail_out
		tail_out=$(printf '%s' "$out" | tail -30)
		if printf '%s' "$tail_out" | grep -qE "Passed|passed|SUCCESS|: OK"; then
			printf '%s' "$tail_out" | grep -E "Passed|passed|SUCCESS|: OK" | tail -1 || true
		else
			printf '%s' "$out" | grep -E "FAIL|FAILED|SCRIPT ERROR|Parse Error" | head -5 || true
			echo "FAILED: $t"
			failed=$((failed + 1))
		fi
	done
	if [[ $failed -gt 0 ]]; then
		echo "--- Ultravibe tests: $failed failed ---"
		return 1
	fi
	echo "--- Ultravibe tests: all passed ---"
	return 0
}
