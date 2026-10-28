# `nix develop` in docs/: a numtide/devshell. Its commands are a sink: each aspect gives the commands of its part.
# Every command runs from the repo root, whatever the directory: `nix develop ./docs` from the root, or `nix develop` in docs/.
{ sven, lib, inputs, ... }:
let
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
  cmd = category: name: help: command: { inherit category name help; command = "set -eu; cd \"$(git rev-parse --show-toplevel)\"; ${command}"; }; # from any directory of the repo
  empty = what: expr: ''out=$(${expr}); echo "${what} = $out"; test "$out" = "[ ]"'';
in
{
  sven.kinds.site.sinks.commands.out = { commands, ... }: {
    devShells.x86_64-linux.default = inputs.devshell.legacyPackages.x86_64-linux.mkShell {
      name = "sven-docs";
      packages = [ pkgs.nodejs pkgs.pnpm pkgs.jq pkgs.git ];
      commands = lib.concatLists commands; # each aspect gives a list
    };
  };

  sven.aspects.docs-commands = {
    at = sven.kinds.site;
    commands = [
      (cmd "docs" "docs-write" "write the pages and the sidebar from examples/" "cd docs && nix run .#write-files")
      (cmd "docs" "docs-test" "the checks of every example (fast)" "cd docs && ${empty "failed" "nix eval --impure --file tests.nix failed"}")
      (cmd "docs" "docs-e2e" "real NixOS, nix-darwin and home-manager evaluations of the examples" "cd docs && ${empty "e2e.failed" "nix eval --impure --file tests.nix e2e.failed"}")
      (cmd "docs" "docs-check" "nix flake check of docs/: pages current, examples, e2e" "cd docs && nix flake check -L")
      (cmd "docs" "docs-dev" "the site at localhost:4321, live" "cd docs && pnpm install && pnpm dev")
      (cmd "docs" "docs-build" "build the site to docs/dist" "cd docs && pnpm install --frozen-lockfile && pnpm build")
    ];
  };
  sven.aspects.fmt-commands = {
    at = sven.kinds.site;
    commands = [
      (cmd "fmt" "fmt-check" "every tracked nix file is formatted (nixfmt), as CI checks" "git ls-files -z '*.nix' | xargs -0 nix run nixpkgs#nixfmt-rfc-style -- --check")
      (cmd "fmt" "fmt" "format every tracked nix file (nixfmt)" "git ls-files -z '*.nix' | xargs -0 nix run nixpkgs#nixfmt-rfc-style --")
    ];
  };
  sven.aspects.engine-commands = {
    at = sven.kinds.site;
    commands = [
      (cmd "engine" "engine-test" "the engine and library oracles" (empty "failed" "nix-instantiate --eval --strict tests -A failed"))
      (cmd "engine" "engine-cost" "the memo cost oracles" "bash tests/cost.sh")
    ];
  };
  sven.aspects.fleet-commands = {
    at = sven.kinds.site;
    commands = [
      (cmd "fleet" "fleet-test" "the reference fleet's checks" "cd templates/fleet && ${empty "failed" "nix eval --impure --file tests.nix failed"}")
      (cmd "fleet" "fleet-e2e" "the reference fleet's real evaluations" "cd templates/fleet && ${empty "e2e.failed" "nix eval --impure --file tests.nix e2e.failed"}")
      (cmd "fleet" "fleet-cost" "the trimmed-module-list cost oracle" "cd templates/fleet && bash cost.sh")
      (cmd "fleet" "fleet-mcp" "the MCP server tests" "bash templates/fleet/mcp/test.sh")
      (cmd "fleet" "fleet-check" "nix flake check of the fleet (the VM test needs KVM)" "nix flake check -L \"path:$PWD?dir=templates/fleet\"")
      (cmd "fleet" "fleet-write" "regenerate the fleet's README.md and ci.json" "cd templates/fleet && nix run .#write-files")
      (cmd "fleet" "fleet-flake" "regenerate the fleet's flake.nix" "cd templates/fleet && nix run .#write-flake")
    ];
  };
  # every CI job of .github/workflows/test.yml, in order, stopping at the first failure
  sven.aspects.ci-command = {
    at = sven.kinds.site;
    commands = [ (cmd "ci" "ci" "run the CI stages locally, in order: fmt, engine, docs, fleet (fleet-check and the per-arch evals not included)"
      "for c in fmt-check engine-test engine-cost docs-test docs-e2e docs-check docs-build fleet-test fleet-e2e fleet-cost fleet-mcp; do echo \"== $c\"; $c; done") ];
  };
}
