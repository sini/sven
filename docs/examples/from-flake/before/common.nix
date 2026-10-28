{ pkgs, ... }:
{
  boot.loader.systemd-boot.enable = true;
  time.timeZone = "UTC";
  services.openssh.enable = true;
  users.users.alice = { isNormalUser = true; extraGroups = [ "wheel" ]; };
  environment.systemPackages = [ pkgs.git ];
  system.stateVersion = "25.05";
}
