# The MCP server as a flake app: `nix run .#sven-mcp` from the fleet directory serves the fleet in $PWD on stdio.
# The script and its tool.nix are copied to the store; the fleet is read from the working tree, so answers follow edits.
{
  sven,
  lib,
  inputs,
  ...
}:
let
  app =
    system:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
    in
    pkgs.writeShellApplication {
      name = "sven-mcp";
      runtimeInputs = [
        pkgs.jq
        pkgs.coreutils
        pkgs.git
      ]; # nix itself comes from the caller's PATH: its version, its store
      text = ''
        export SVEN_FLEET="''${SVEN_FLEET:-$PWD}"
        exec ${../../mcp}/sven-mcp.sh "$@"
      '';
    };
in
{
  sven.aspects.mcp-app = {
    at = sven.kinds.fleet;
    out =
      { ... }:
      {
        apps = lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system: {
          sven-mcp = {
            type = "app";
            program = "${app system}/bin/sven-mcp";
            meta.description = "sven MCP server over the fleet in the working directory";
          };
        });
      };
  };
}
