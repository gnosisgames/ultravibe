#!/usr/bin/env bash
# Mod integration tests — require --enable-mods (mods are off by default).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/../scripts/resolve_godot.sh"
# shellcheck source=/dev/null
source "$(dirname "$0")/_test_runner.sh"

MOD_TESTS=(
	test_mod_boon_catalog
	test_mod_drizzle_shop_diagnostic
)

run_godot_tests "$ROOT" --enable-mods "${MOD_TESTS[@]}"
