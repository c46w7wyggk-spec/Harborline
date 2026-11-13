#!/usr/bin/env bash
# Runs every automated check available outside Roblox Studio.
# Needs: lune, stylua, rojo (see docs/BETA_HANDOFF.md "Toolchain").
set -euo pipefail
cd "$(dirname "$0")/.."
echo "== format (stylua --check)"; stylua --check src tests
echo "== syntax (Luau compiler)";  lune run tests/compile_all
echo "== unit tests";              lune run tests/run
echo "== smoke (world, vehicles, UI vs Roblox reflection DB)"; lune run tests/smoke_world
echo "== place build (rojo)";      mkdir -p build && rojo build -o build/Harborline.rbxlx
echo "ALL CHECKS PASSED"
