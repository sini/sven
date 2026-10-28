# den#739: Den cannot pipe host data (a quirk) to a standalone home `tux@igloo`, only to a home-manager module home.
# In sven, where a scope lives (spawns) and what it builds (its sink's `out`) are separate. The home `alice@stage`
# lives under host stage, so it reads stage's `monitor` sink like any child, and still builds a standalone
# `homeConfigurations."alice@stage"`.
{ sven, lib, ... }:
let
  inherit (sven.lib) same maybe;
in
{
  sven.kinds.home.fields.on = maybe sven.kinds.host;
  sven.kinds.host.spawns.home = s: lib.filterAttrs (_: h: same h.on s) sven.home;
  sven.kinds.host.sinks.monitor.reduce = sven.lib.reduce.merge;
  sven.kinds.home.sinks.os = { }; # a wall: the home's users give `os` here, and nothing reads it, so stage's NixOS stays untouched
  sven.home."alice@stage" = { user = sven.user.alice; channel = sven.channel.edge; system = sven.system.x86_64-linux; on = sven.host.stage; };
  sven.aspects.stage-monitor = { at = sven.host.stage; monitor = { resolution = "2560x1440"; scale = 1.5; }; };
  sven.aspects.monitor-env = {
    at = sven.lib.all [ sven.kinds.user (sven.lib.within sven.kinds.home) ];
    homeManager = { monitor ? null, ... }: lib.optionalAttrs (monitor != null) { home.sessionVariables.MONITORRES = monitor.resolution; };
  };
}
