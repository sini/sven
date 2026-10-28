# One aspect, two platform keys: each key lands where its sink is.
{ sven, ... }:
let
  inherit (sven.lib) all within;
in
{
  sven.aspects.hm-module = {
    at = sven.helpers.machines;
    nixos = { scope, ... }: { imports = [ scope.channel.home-manager.nixosModules.home-manager ]; };
    darwin = { scope, ... }: { imports = [ scope.channel.home-manager.darwinModules.home-manager ]; };
  };
  sven.aspects.hm-state = { at = sven.kinds.user; homeManager.home.stateVersion = "25.05"; };
  sven.aspects.hm-standalone = {
    at = all [ sven.kinds.user (within sven.kinds.home) ];
    homeManager = { user, ... }: { home.username = user.name; home.homeDirectory = "/home/${user.name}"; };
  };
  sven.aspects.ssh-agent = { at = all [ sven.kinds.user (within sven.helpers.linux) ]; homeManager.services.ssh-agent.enable = true; };   # the home-manager service is Linux only
  sven.aspects.htop = { at = all [ sven.user.alice (within sven.host.web-1) ]; homeManager.programs.htop.enable = true; }; # host-qualified
  sven.aspects.tiling = { at = sven.kinds.user; homeDarwin.programs.aerospace.enable = true; }; # only mac users have homeDarwin
  sven.aspects.dev = { at = [ sven.helpers.machines sven.kinds.user ]; os = { pkgs, ... }: { environment.systemPackages = [ pkgs.git ]; }; homeManager.programs.git.enable = true; };
}
