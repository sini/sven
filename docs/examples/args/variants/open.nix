# `pkgs` is not a kind, a sink or `scope`: it stays open. The element is a module function.
{ sven, ... }:
{
  sven.aspects.open = {
    at = sven.host.lb;
    proxy =
      { host, pkgs, ... }:
      {
        name = host.name;
        shell = pkgs.bash;
      };
  };
}
