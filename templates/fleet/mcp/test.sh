#!/usr/bin/env bash
# Drives sven-mcp.sh with JSON-RPC lines. Run from anywhere; each call is capped at 300 s.
set -u
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
SRV=${SVEN_MCP_SERVER:-$HERE/sven-mcp.sh}
fails=0

rpc() { printf '%s\n' "$1" | timeout -k 5 300 "$SRV"; }
call() { rpc "$(jq -cn --arg n "$1" --argjson a "$2" '{jsonrpc:"2.0",id:1,method:"tools/call",params:{name:$n,arguments:$a}}')"; }
text() { jq -c '.result.content[0].text | fromjson'; } # the wrapped { complete, result | error }
check() { # name jq-filter input-json
  if jq -e "$2" <<<"$3" >/dev/null 2>&1; then echo "PASS $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi
}

out=$(rpc '{"jsonrpc":"2.0","id":1,"method":"initialize"}')
check initialize '.result.serverInfo.name == "sven-mcp"' "$out"

out=$(rpc '{"jsonrpc":"2.0","id":1,"method":"tools/list"}')
check tools-list '(.result.tools | map(.name) | sort) == ["sven_check","sven_context","sven_declared_in","sven_errors","sven_explain","sven_export","sven_schema","sven_stage"]' "$out"

out=$(call sven_schema '{}' | text)
check schema '.complete == true and (.result.kinds | has("host"))' "$out"

out=$(call sven_context '{"id":"fleet:mian"}' | text)
check context-unknown '.result.code == "unknown-scope" and (.result.near | length > 0)' "$out"

out=$(call sven_errors '{}' | text)
check errors-list '.complete == true and (.result | type == "array")' "$out"

out=$(call sven_stage '{"change":{"sven":{"aspects":{"attic":{"at":[{"kind":"mac","name":"studio"}]}}}}}' | text)
check stage-attic '.result.ok == false and (.result.violations | map(contains("attic-on-mac")) | any)' "$out"

out=$(SVEN_TIMEOUT=1 call sven_export '{}' | text)
check export-timeout '.complete == false and .error == "timeout"' "$out"


out=$(call sven_export '{}' | text)
check export-full '.complete == true and (.result.sha256 | length == 64) and (.result.count > 0)' "$out"

out=$(call sven_context '{}')
check eval-error '.result.isError == true and (.result.content[0].text | fromjson | .complete == false and (.error | length > 0))' "$out"

# the flake app: `nix run .#sven-mcp` from the fleet directory (set SVEN_MCP_SKIP_APP=1 to skip)
if [ -z "${SVEN_MCP_SKIP_APP:-}" ]; then
  out=$(cd "$HERE/.." && printf '%s\n' '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"sven_context","arguments":{"id":"fleet:main/environment:lab/host:app-1","maxEdges":2}}}' \
    | timeout -k 5 600 nix run "path:$(git rev-parse --show-toplevel)?dir=templates/fleet#sven-mcp" 2>/dev/null)
  check flake-app '.result.content[0].text | fromjson | .complete == true and .result.kind == "host" and .result.given.truncated.shown == 2' "$out"
fi
[ "$fails" -eq 0 ]
