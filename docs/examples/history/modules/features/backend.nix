{ sven, ... }:
{
  sven.aspects.backend = {
    at = sven.kinds.host;
    backends = { host, ... }: host.name;
  };
}
