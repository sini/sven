# den.default: an aspect at every scope of a kind.
{ sven, ... }:
{
  sven.aspects.state-version = {
    at = sven.kinds.host;
    nixos.system.stateVersion = "25.05";
  };
  sven.aspects.home-state-version = {
    at = sven.kinds.user;
    homeManager.home.stateVersion = "25.05";
  };
}
