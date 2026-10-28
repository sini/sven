# Instances: `sven.<kind>.<name>`. The name is the attribute name.
{ sven, ... }:
{
  sven.host.web = { addr = "10.0.0.1"; cores = 4; };
  sven.host.db = { addr = "10.0.0.2"; cores = 16; };
}
