# Guests: a microvm on a host. Its nixos forwards to the host (a key with the sink's own name goes up).
{ sven, lib, ... }:
{
  sven.kinds.guest = {
    fields = sven.kinds.machine.fields // { on = sven.kinds.host; };
    spawns.user = sven.helpers.usersOn; # no spawns.guest: no guest in a guest
    sinks = {
      nixos.nixos = { guest, nixos, ... }: { microvm.vms.${guest.name} = { pkgs = sven.helpers.pkgsOf guest; config.imports = nixos; }; };
      inherit (sven.kinds.host.sinks) os persist age-secrets unfree;
    };
  };
}
