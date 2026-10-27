# web-1 and web-2 come from JSON: their names become refs.
{ sven, lib, ... }:
{
  sven.host = lib.mapAttrs
    (_: h: h // { environment = sven.environment.${h.environment}; channel = sven.channel.${h.channel}; system = sven.system.${h.system}; })
    (lib.importJSON ./_inventory.json);
}
