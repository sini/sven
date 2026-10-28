# Shared pkgs, measured: the toplevel drvPaths of app-1..3, either sharing app-1's pkgs or each with its own.
# Run (capped) with NIX_SHOW_STATS=1 and compare nrThunks / cpuTime:  --arg shared true  vs  --arg shared false
{ shared ? true }:
let
  r = import ./query.nix;
  o = r.flake;
  d = c: c.config.system.build.toplevel.drvPath;
in
[ (d o.nixosConfigurations.app-1) ]
++ map (n: d (if shared then o.nixosConfigurations.${n} else o.nixosConfigurationsOwnPkgs.${n})) [ "app-2" "app-3" ]
