# A sink's other keys give elements to other sinks. They run at the receiver, with its args.
{ sven, ... }:
let
  inherit (sven.lib.reduce) merge;
in
{
  sven.kinds.host.sinks = {
    ports.config = { ports, ... }: { firewall.allowedTCPPorts = ports; }; # ports feed config
    config = { reduce = merge; out = { host, config, ... }: { config.${host.name} = config; }; };
  };
  sven.kinds.guest.sinks = {
    ports.config = { ports, ... }: { firewall.allowedTCPPorts = ports; };
    config = {
      reduce = merge;
      config = { guest, config, ... }: { vms.${guest.name} = config; }; # its own name: a forward up, to the host
    };
  };
}
