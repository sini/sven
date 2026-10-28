# fleet > environment > host > user and home. Who receives an element depends on where the sinks are.
{ sven, lib, ... }:
let
  inherit (sven.lib) same opt;
  under = field: kind: s: lib.filterAttrs (_: x: same x.${field} s) kind;
in
{
  sven.kinds.fleet = {
    spawns.environment = _: sven.environment;
    sinks.out.reduce = sven.lib.reduce.merge;
    sinks.dns.out = { dns, ... }: { dns.fleet = dns; }; # the fallback receiver
  };
  sven.kinds.environment = {
    fields.public = opt lib.types.bool false;
    spawns.host = under "environment" sven.host;
    sinks.dns = {
      at = s: s.public; # a conditional receiver: only public environments
      out = { environment, dns, ... }: { dns.${environment.name} = dns; };
    };
  };
  sven.kinds.host = {
    fields.environment = sven.kinds.environment;
    spawns = { user = under "on" sven.user; home = under "on" sven.home; };
    sinks.os.out = { host, os, ... }: { os.${host.name} = os; };
  };
  sven.kinds.user.fields.on = sven.kinds.host;
  sven.kinds.home = {
    fields.on = sven.kinds.host;
    sinks.os.out = { home, os, ... }: { os.${home.name} = os; }; # a home builds its own config
  };

  sven.fleet.main = { };
  sven.flake = { out, ... }: out;
}
