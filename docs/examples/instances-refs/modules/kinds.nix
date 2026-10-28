# A kind is a type too: a field of kind `environment` holds a ref to an environment instance.
# Nothing spawns `environment`, so it is a data kind: its instances have no scope.
{ sven, lib, ... }:
{
  sven.kinds.environment.fields.domain = lib.types.str;
  sven.kinds.host.fields = {
    environment = sven.kinds.environment;
    backup = sven.lib.maybe sven.kinds.host; # a ref to another host, or null
  };
}
