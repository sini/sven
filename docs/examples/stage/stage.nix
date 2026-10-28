# Stage a change file against the fleet. Nothing is applied.
#   nix eval --impure --json --file stage.nix --argstr change changes/desktop-on-web.json
{
  change,
  grant ? null, # where the change may give elements: sven.lib.grant { scopes = [ … ]; }
  rejected ? [ ], # sha256 of changes refused before
  sven ? builtins.fetchTarball "https://github.com/vic/sven/archive/main.tar.gz",
  nixpkgs ? builtins.fetchTarball "https://nixos.org/channels/nixos-25.05/nixexprs.tar.xz",
  import-tree ? import (builtins.fetchTarball "https://github.com/denful/import-tree/archive/main.tar.gz"),
}:
let
  base = { imports = [ (import-tree ./modules) ]; _module.args = { lib = import "${nixpkgs}/lib"; }; };
  s = (import sven).lib.stage { inherit base grant rejected; change = builtins.fromJSON (builtins.readFile (./. + "/${change}")); };
in
removeAttrs s [ "render" ]
