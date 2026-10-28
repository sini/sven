# A set collector with a per-host filter (sini cortex-cuda `unpersist`).
{
  sven,
  lib,
  inputs,
  ...
}:
{
  sven.kinds.machine.fields.unpersist = sven.lib.opt (sven.helpers.listOf lib.types.str) [ ];
  sven.host.web-2.unpersist = [ "/var/lib/nginx" ];
  sven.kinds.host.sinks.persist = {
    of = lib.types.str;
    reduce = sven.lib.reduce.set;
    nixos =
      { scope, persist, ... }:
      {
        imports = [ inputs.impermanence.nixosModules.impermanence ];
        environment.persistence."/persist".directories = lib.subtractLists scope.unpersist persist;
      };
  };
}
