# A sink with no keys is a wall: a home's packages stop at the home and never reach the host.
{ sven, ... }:
{
  sven.kinds.host.sinks.packages.out = { host, packages, ... }: { packages.${host.name} = packages; };
  sven.kinds.home.sinks.packages = { };
  sven.aspects.editor = {
    at = [ sven.kinds.user sven.kinds.home ];
    packages = { scope, ... }: "vim for ${scope.name}";
  };
}
