#!/usr/bin/env sh
set -eu

# Generate the GraphViz call graph for HamiltonSim.simulate_file
#
# Usage:
#   sh scripts/generate_call_graph.sh
#
# Outputs:
#   output/call_graph.dot
#   output/call_graph.dot.svg  (if GraphViz 'dot' is installed)

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DOT_OUT="$REPO_ROOT/output/call_graph.dot"

cd "$REPO_ROOT"

julia scripts/call_graph.jl --out "$DOT_OUT"

if command -v dot >/dev/null 2>&1; then
  julia scripts/call_graph.jl --out "$DOT_OUT" --render svg
else
  echo "GraphViz 'dot' not found; skipping SVG render" >&2
fi
