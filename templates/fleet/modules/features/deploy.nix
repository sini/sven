# deploy is `one` per host; tags are a set; vars are generated-value plans, never values.
{ sven, ... }:
{
  sven.aspects.deploy-record = {
    at = sven.kinds.host;
    deploy = { host, ... }: { address = host.addr; user = "deploy"; inherit (host) buildHost; };
    vars = { host, ... }: { per-machine.${host.name}.deploy-key.files = [ "key" "key.pub" ]; };
  };
  sven.aspects.ca = { at = sven.fleet.main; vars.shared.ca.files = [ "ca.crt" "ca.key" ]; };
}
