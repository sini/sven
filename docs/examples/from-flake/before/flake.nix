# A typical flake: a helper builds each host from shared and per-host modules.
{
  inputs.nixpkgs.url = "https://nixos.org/channels/nixos-25.05/nixexprs.tar.xz";
  inputs.home-manager = {
    url = "github:nix-community/home-manager/release-25.05";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { nixpkgs, home-manager, ... }:
    let
      mkHost =
        name:
        nixpkgs.lib.nixosSystem {
          modules = [
            ./common.nix
            ./hosts/${name}.nix
            home-manager.nixosModules.home-manager
            {
              networking.hostName = name;
              home-manager.useGlobalPkgs = true;
              home-manager.users.alice = import ./home.nix;
            }
          ];
        };
    in
    {
      nixosConfigurations.web = mkHost "web";
      nixosConfigurations.desk = mkHost "desk";
    };
}
