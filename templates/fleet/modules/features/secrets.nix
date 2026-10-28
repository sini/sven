# Per-aspect flake inputs (flake-file) and module imports. vm-host: a host that has a guest.
{ sven, inputs, ... }:
{
  sven.aspects.secrets = {
    at = sven.kinds.host;
    nixos.imports = [ inputs.agenix.nixosModules.default ];
    flake-file.inputs.agenix.url = "github:ryantm/agenix";
  };
  sven.aspects.vm = {
    at = sven.kinds.guest;
    nixos.imports = [ inputs.microvm.nixosModules.microvm ];
    flake-file.inputs.microvm.url = "github:microvm-nix/microvm.nix";
  };
  sven.aspects.vm-host = {
    at = sven.lib.all [
      sven.kinds.host
      (sven.lib.has sven.kinds.guest)
    ];
    nixos.imports = [ inputs.microvm.nixosModules.host ];
  };
}
