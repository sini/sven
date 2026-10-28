{ sven, ... }:
{
  sven.host.web = { };
  sven.aspects.web-hardware = {
    at = sven.host.web;
    nixos = {
      fileSystems."/" = { device = "/dev/sda1"; fsType = "ext4"; };
      nixpkgs.hostPlatform = "x86_64-linux";
    };
  };
}
