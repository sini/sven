# A guest lives under its host. Its own `nixos` sink forwards up, into the host's containers.
{ sven, lib, inputs, ... }:
{
  sven.kinds.fleet = {
    spawns.host = _: sven.host;
    sinks.out.reduce = sven.lib.reduce.merge;
  };
  sven.kinds.host = {
    spawns.guest = s: lib.filterAttrs (_: g: sven.lib.same g.on s) sven.guest;
    sinks.nixos.out = { host, nixos, ... }: {
      nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem { modules = nixos; };
    };
  };
  sven.kinds.guest = {
    fields.on = sven.kinds.host;
    sinks.nixos.nixos = { guest, nixos, ... }: {
      containers.${guest.name} = { autoStart = true; config.imports = nixos; };
    };
  };

  sven.fleet.main = { };
  sven.flake = { out, ... }: out;
}
