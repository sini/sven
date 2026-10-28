# Two kinds of machine, one `os` sink: an aspect writes `os` once, and each platform forwards it.
{ sven, inputs, ... }:
{
  sven.kinds.fleet = {
    spawns = {
      host = _: sven.host;
      mac = _: sven.mac;
    };
    sinks.out.reduce = sven.lib.reduce.merge;
  };
  sven.kinds.host.sinks = {
    os.nixos =
      { os, ... }:
      {
        imports = os;
      };
    nixos.out =
      { host, nixos, ... }:
      {
        nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem { modules = nixos; };
      };
  };
  sven.kinds.mac.sinks = {
    os.darwin =
      { os, ... }:
      {
        imports = os;
      };
    darwin.out =
      { mac, darwin, ... }:
      {
        darwinConfigurations.${mac.name} = inputs.nix-darwin.lib.darwinSystem { modules = darwin; };
      };
  };

  sven.fleet.main = { };
  sven.flake = { out, ... }: out;
}
