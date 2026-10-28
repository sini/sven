# /etc/nixos/configuration.nix, as nixos-generate-config leaves it, plus a few edits.
{ pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  networking.hostName = "laptop";
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  services.openssh.enable = true;
  users.users.alice = { isNormalUser = true; extraGroups = [ "wheel" ]; };
  environment.systemPackages = with pkgs; [ git vim ];

  system.stateVersion = "25.05";
}
