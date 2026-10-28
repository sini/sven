{
  den.aspects.igloo = {
    nixos = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.hello ];
      boot.loader.grub.enable = false;
      fileSystems."/" = { device = "/dev/fake"; fsType = "auto"; };
    };
    provides.to-users.homeManager = { pkgs, ... }: { home.packages = [ pkgs.vim ]; };
  };
}
