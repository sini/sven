# One system scope per platform: per-system flake outputs.
{
  sven,
  lib,
  inputs,
  ...
}:
let
  inherit (sven.lib.reduce) merge;
  pkgs = s: inputs.nixpkgs.legacyPackages.${s.name};
in
{
  sven.kinds.system.sinks = {
    packages = {
      reduce = merge;
      out =
        { system, packages, ... }:
        {
          packages.${system.name} = packages;
        };
    };
    checks = {
      reduce = merge;
      out =
        { system, checks, ... }:
        {
          checks.${system.name} = lib.mapAttrs (
            name: m:
            (pkgs system).testers.runNixOSTest {
              imports = [ m ];
              inherit name;
            }
          ) checks;
        };
    };
    no-gui = {
      # reads the realized lb from `out`, writes `out.checks`: laziness, not strata
      of = lib.types.attrsOf (lib.types.listOf lib.types.str);
      reduce = merge;
      out =
        {
          system,
          out,
          no-gui,
          ...
        }:
        {
          checks.${system.name} = lib.mapAttrs' (
            h: bad:
            lib.nameValuePair "${h}-no-gui" (sven.helpers.noGui system h out.nixosConfigurations.${h} bad)
          ) no-gui;
        };
    };
  };
  sven.system = lib.genAttrs [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ] (_: { });
}
