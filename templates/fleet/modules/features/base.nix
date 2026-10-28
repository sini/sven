# base: every machine. Its `records` key lives in dns.nix: one aspect, two files.
{ sven, lib, ... }:
{
  sven.aspects.base = {
    at = sven.helpers.machines;
    os = { scope, overlays, ... }: { networking.hostName = scope.name; nixpkgs.overlays = overlays; };
  };
  sven.aspects.hardware = { # enough for a real toplevel
    at = sven.kinds.host;
    nixos = {
      fileSystems."/" = { device = "/dev/disk/by-label/root"; fsType = "ext4"; };
      fileSystems."/persist" = { device = "/dev/disk/by-label/persist"; fsType = "ext4"; neededForBoot = true; };
      boot.loader.grub.device = "nodev";
    };
  };
  sven.aspects.state-version = { at = sven.helpers.linux; nixos.system.stateVersion = "25.05"; };
  sven.aspects.user-account = { at = sven.lib.all [ sven.kinds.user (sven.lib.within sven.helpers.linux) ]; account.isNormalUser = true; };   # NixOS only
  sven.aspects.user-account-mac = { at = sven.lib.all [ sven.kinds.user (sven.lib.within sven.kinds.mac) ]; account = { user, ... }: { home = "/Users/${user.name}"; }; };
}
