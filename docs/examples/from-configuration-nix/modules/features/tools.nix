# `pkgs` stays open: NixOS fills it.
{ sven, ... }:
{
  sven.aspects.tools = {
    at = sven.kinds.host;
    nixos = { pkgs, ... }: { environment.systemPackages = with pkgs; [ git vim ]; };
  };
}
