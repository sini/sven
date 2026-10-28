# Step one: the whole old file as one aspect. Use it with modules/fleet.nix and modules/laptop.nix only.
{ sven, ... }:
{
  sven.aspects.legacy = {
    at = sven.host.laptop;
    nixos = ../before/configuration.nix;
  };
}
