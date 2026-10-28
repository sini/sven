# Den quirks and pipes, in sven: a quirk is a sink; where it lands is the tree, not a policy.
{ sven, lib, ... }:
{
  # den.quirks.firewall: a sink on the host. A user has no `firewall` sink, so a user's ports go up
  # to its host by routing: Den's `pipe.expose` is the default here.
  sven.kinds.host.sinks.firewall = {
    reduce = sven.lib.reduce.entries; # each value with the scope that gave it: provenance, as in pipe.collect
    nixos =
      { firewall, ... }:
      {
        networking.firewall.allowedTCPPorts = lib.unique (lib.concatMap (e: e.value.ports) firewall);
      };
  };

  # producers do not know the consumer: they give `firewall` elements
  sven.aspects.ssh = {
    at = sven.kinds.host;
    firewall.ports = [ 22 ];
  };
  sven.aspects.tux-dev-server = {
    at = sven.user.tux;
    firewall.ports = [ 3000 ]; # from a user, lands on each of its hosts
  };

  # pipe.filter / pipe.as: a plain reader. Here: the ports that users opened, for a report
  sven.kinds.host.sinks.firewall.out =
    { host, firewall, ... }:
    {
      userPorts.${host.name} = lib.concatMap (e: e.value.ports) (
        lib.filter (e: e.from.kind == "user") firewall
      );
    };
}
