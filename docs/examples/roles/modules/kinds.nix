# Machines carry facts. No host file names its roles: the facts decide.
{ sven, lib, ... }:
let
  inherit (sven.lib) opt is;
in
{
  sven.kinds.fleet = {
    spawns.host = _: sven.host;
    sinks.out.reduce = sven.lib.reduce.merge;
  };
  sven.kinds.host.fields = {
    form = lib.types.enum [
      "server"
      "laptop"
      "desktop"
    ];
    gpu = opt (lib.types.enum [
      "none"
      "nvidia"
      "amd"
    ]) "none";
    labels = opt (is (v: lib.isList v && lib.all lib.isString v)) [ ];
  };

  sven.fleet.main = { };
  sven.host.rack-1 = {
    form = "server";
    labels = [ "ci-runner" ];
  };
  sven.host.rack-2.form = "server";
  sven.host.thinkpad.form = "laptop";
  sven.host.tower = {
    form = "desktop";
    gpu = "nvidia";
  };
  sven.flake = { out, ... }: out;
}
