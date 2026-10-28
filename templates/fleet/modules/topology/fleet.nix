# The root kind: nothing spawns it. Its sinks are the flake outputs and the fleet-wide pools.
{
  sven,
  lib,
  inputs,
  ...
}:
let
  inherit (sven.lib.reduce) merge;
in
{
  sven.kinds.fleet = {
    spawns = {
      environment = _: sven.environment;
      system = _: sven.system;
      home = _: lib.filterAttrs (_: h: h.on == null) sven.home; # homes on a host live under it (den#739)
      replica = _: lib.filterAttrs (_: r: r.db.zone == r.region.zone) sven.replica; # a relation kind: only matching pairs
    };
    sinks = {
      out.reduce = merge;
      vars = {
        reduce = merge;
        out =
          { vars, ... }:
          {
            inherit vars;
          };
      };
      colmena = {
        reduce = merge;
        out =
          { colmena, ... }:
          {
            colmenaHive = inputs.colmena.lib.makeHive (
              { meta.nixpkgs = inputs.nixpkgs.legacyPackages.x86_64-linux; } // colmena
            );
          };
      };
      overlays = { }; # machines read it
      records = {
        of = lib.types.attrsOf lib.types.str;
        reduce = merge;
      }; # every machine's A record; prod reads it
      scrape.of = sven.lib.is (v: lib.isString (v.job or null) && lib.isString (v.target or null));
    };
  };
  sven.fleet.main = { };
  sven.flake = { out, ... }: out;
}
