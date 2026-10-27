# Den: deterministic ids from sorted names (no state). Each host gets its own ssh port.
{ sven, ... }:
{
  sven.aspects.ssh-port = { at = sven.kinds.host; nixos = { host, ... }: { services.openssh.enable = true; services.openssh.ports = [ (2200 + sven.helpers.ids.${host.name}) ]; }; };
}
