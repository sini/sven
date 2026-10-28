# Channels: which nixpkgs and home-manager a machine builds with.
{
  sven,
  lib,
  inputs,
  ...
}:
{
  sven.kinds.channel.fields = {
    nixpkgs = lib.types.raw;
    home-manager = lib.types.raw;
    darwin = sven.lib.opt lib.types.raw null;
  };
  sven.channel.stable = {
    nixpkgs = inputs.nixpkgs;
    home-manager = inputs.home-manager;
    darwin = inputs.nix-darwin;
  };
  sven.channel.edge = {
    nixpkgs = inputs.nixpkgs-unstable;
    home-manager = inputs.home-manager-unstable;
  };
}
