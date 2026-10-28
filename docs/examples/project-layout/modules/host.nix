# eval-config.nix works with a flake input and with a plain nixpkgs path.
{
  sven,
  lib,
  inputs,
  ...
}:
{
  sven.kinds.host = {
    fields.system = lib.types.str;
    sinks.nixos.out =
      { host, nixos, ... }:
      {
        nixosConfigurations.${host.name} = import "${inputs.nixpkgs}/nixos/lib/eval-config.nix" {
          inherit (host) system;
          modules = nixos;
        };
      };
  };

  sven.host.laptop.system = "x86_64-linux";
}
