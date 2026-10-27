# A cascade: host, then its environment, then the environment's base. Data queries, no merge.
{ sven, ... }:
{
  sven.aspects.kernel = {
    at = sven.kinds.host;
    nixos = { host, environment, pkgs, ... }:
      let k = sven.lib.cascade [ "settings" "kernel" "channel" ] [ host environment environment.base ]; in
      { boot.kernelPackages = if k == "lts" then pkgs.linuxPackages else pkgs.linuxPackages_latest; };
  };
  sven.aspects.facter = {
    at = sven.kinds.host;
    nixos = { host, lib, ... }: let r = ../../facter + "/${host.name}.json"; in lib.optionalAttrs (builtins.pathExists r) { hardware.facter.reportPath = r; };
  };
}
