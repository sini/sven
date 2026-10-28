# clan services written in sven. A service is data (roles, typed interface, constraints, nested instances) plus
# aspects: an aspect at a member scope is clan's perInstance, an aspect at a machine that `has` a member is perMachine.
# borg comes from another file through a function, as clan's `module.input` loads a service from another flake.
{ sven, lib, ... }:
let
  inherit (sven.lib) all has;
  memberOf = svc: role: s: s.service or null == svc && (role == null || s.role == role);
  at = svc: role: all [ sven.kinds.member (memberOf svc role) ];
  str = lib.types.str;
in
{
  imports = [ (import ../../services/borg.nix { prefix = "fleet"; }) ];

  sven.helpers.clan.services = {
    sshd.roles.server = { };
    wifi.roles.default.interface.networks = { type = lib.types.attrs; default = { }; };
    users = { roles.default.interface.user = { type = str; }; };
    banner = { roles.default.interface.text = { type = str; default = "managed by sven"; }; constraints.maxInstances = 1; };
  };

  # sshd: one config per machine however many instances (perMachine)
  sven.aspects.clan-sshd = { at = all [ sven.helpers.machines (has (memberOf "sshd" null)) ]; os.services.openssh.enable = true; };
  # wifi: the settings a member reads are interface defaults, then role-wide, then this machine's
  sven.aspects.clan-wifi = { at = at "wifi" "default"; nixos = { member, ... }: { environment.etc."wifi/networks".text = toString (lib.attrNames member.settings.networks); }; };
  # users: many instances of one service on one machine, each its own scope
  sven.aspects.clan-users = { at = at "users" "default"; nixos = { member, ... }: { users.users.${member.settings.user} = { isSystemUser = true; group = "nogroup"; }; }; };
  sven.aspects.clan-banner = { at = at "banner" "default"; os = { member, ... }: { environment.etc."banner".text = member.settings.text; }; };

  # instances (clan inventory.instances); labels are clan tags
  sven.host.stage.labels = [ "laptop" ];
  sven.instance = {
    backup = { module = "borg"; roles = { client = { tags = [ "nixos" ]; settings.startAt = "02:00"; }; server.machines.lb = { }; }; };
    wifi.roles.default = { tags = [ "laptop" ]; settings.networks.home = { }; machines.stage.settings.networks.office = { }; };
    svc-a = { module = "users"; roles.default = { machines.lb = { }; settings.user = "svc-a"; extraModules = [ { environment.etc."extra".text = "svc-a"; } ]; }; };
    svc-b = { module = "users"; roles.default = { machines.lb = { }; settings.user = "svc-b"; }; };
    banner.roles.default.tags = [ "darwin" ];
    sshd.roles.server.tags = [ "all" ];
  };
}
