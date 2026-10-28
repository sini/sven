# den.hosts.x86_64-linux.igloo.users.tux, and the igloo aspect.
{ sven, ... }:
{
  sven.host.igloo.system = "x86_64-linux";
  sven.aspects.igloo = {
    at = sven.host.igloo;
    nixos = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.hello ];
      boot.loader.grub.enable = false;
      fileSystems."/" = { device = "/dev/fake"; fsType = "auto"; };
    };
  };
  # provides.to-users: content for the users of igloo, given at each user
  sven.aspects.igloo-users = {
    at = sven.lib.all [ sven.kinds.user (sven.lib.within sven.host.igloo) ];
    homeManager = { pkgs, ... }: { home.packages = [ pkgs.vim ]; };
  };
}
