#!/usr/bin/env bash
# Cost oracles: the memos are behavior an eval cannot see, so these bound Nix's own counters (NIX_SHOW_STATS).
#   aspect-ref memo: 30 levels of diamonds; without the memo it is 2^30 reads (a timeout counts as a failure)
#   reduction memo : 150 hosts read one costly sink; without the memo each read reduces again (~n^2)
# Run from the repository root: bash tests/cost.sh   (each case capped at 30 s)
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fails=0
bound() { # name expr max-function-calls
  if NIX_SHOW_STATS=1 NIX_SHOW_STATS_PATH="$tmp/$1.json" timeout 30 nix-instantiate --eval --strict -E "$2" >/dev/null 2>"$tmp/$1.err"; then
    calls=$(jq '.nrFunctionCalls' "$tmp/$1.json"); thunks=$(jq '.nrThunks' "$tmp/$1.json")
    if [ "$calls" -le "$3" ]; then echo "PASS $1 calls=$calls thunks=$thunks (max $3)"; else echo "FAIL $1 calls=$calls thunks=$thunks (max $3)"; fails=$((fails + 1)); fi
  else echo "FAIL $1 (exit $?, timeout or error)"; fails=$((fails + 1)); fi
}
bound aspect-ref-memo 'import ./tests/cost/diamond.nix { k = 30; }' 200000
bound reduction-memo 'import ./tests/cost/fanin.nix { n = 150; }' 200000
exit $fails
