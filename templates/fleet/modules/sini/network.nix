# Conditional environment receivers fed by hosts (terranix, unifi port-forwards).
{ sven, lib, inputs, ... }:
let
  inherit (sven.lib) maybe;
in
{
  sven.kinds.environment.fields = { dns.publicIPv4 = maybe lib.types.str; unifi = maybe lib.types.attrs; };
  sven.environment.prod = { dns.publicIPv4 = "203.0.113.1"; unifi.site = "default"; };
  sven.kinds.environment.sinks = {
    terranix = {
      at = s: s.dns.publicIPv4 != null;
      out = { environment, terranix, ... }: { terranixConfigurations."dns-${environment.name}" = inputs.terranix.lib.terranixConfiguration { system = "x86_64-linux"; modules = terranix; }; };
    };
    unifi = { at = s: s.unifi != null; out = { environment, unifi, ... }: { unifiTerranixModules.${environment.name} = unifi; }; };
    port-forwards = { };
  };
  sven.aspects.headscale = { at = sven.host.lb; port-forwards = { host, ... }: { name = "headscale"; wanPort = 443; forward = host.addr; }; };
  sven.aspects.unifi-forwards = {
    at = sven.lib.all [ sven.kinds.environment (s: s.unifi != null) ];
    unifi = { port-forwards, ... }: { resource.unifi_port_forward = lib.listToAttrs (map (p: lib.nameValuePair p.name { dst_port = toString p.wanPort; fwd_ip = p.forward; }) port-forwards); };
  };
  sven.aspects.public-dns = { at = sven.environment.prod; terranix = { environment, ... }: { resource.cloudflare_record.apex = { value = environment.dns.publicIPv4; type = "A"; }; }; };
}
