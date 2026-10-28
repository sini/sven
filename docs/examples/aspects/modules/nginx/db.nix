{ sven, ... }:
{
  sven.aspects.nginx = {
    at = sven.host.db;
    packages = { host, ... }: "nginx-conf-${host.name}"; # a function under the same key: one more element
  };
}
