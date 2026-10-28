{
  inputs = {
    sven = {
      url = "path:../..";
      flake = false;
    };
    import-tree.url = "github:denful/import-tree";
    files.url = "github:sini/files";
    flake-file.url = "github:vic/flake-file";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager-unstable = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    colmena.url = "github:zhaofengli/colmena";
    nix-on-droid.url = "github:nix-community/nix-on-droid";
    terranix.url = "github:terranix/terranix";
    agenix.url = "github:ryantm/agenix";
    microvm.url = "github:microvm-nix/microvm.nix";
    impermanence.url = "github:nix-community/impermanence";
  };
  # sven knows nothing of flakes or inputs: the fleet passes them down as module args.
  outputs =
    inputs:
    (import inputs.sven).lib.mkFlake {
      imports = [ (inputs.import-tree ./modules) ];
      _module.args = {
        inherit inputs;
        inherit (inputs.nixpkgs) lib;
      };
    };
}
