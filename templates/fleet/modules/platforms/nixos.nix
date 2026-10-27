# NixOS hosts: the nixos sink builds the system; os fans out to nixos (#76).
{ sven, lib, ... }:
let
  inherit (sven.lib) same;
  inherit (sven.lib.reduce) one;
in
{
  sven.kinds.host = {
    fields = sven.kinds.machine.fields;
    spawns = {
      user = sven.helpers.usersOn;
      guest = s: lib.filterAttrs (_: g: same g.on s) sven.guest;
    };
    sinks = {
      nixos = {
        out = { host, nixos, deploy, ... }:
          let sys = host.channel.nixpkgs.lib.nixosSystem { system = host.system.name; modules = nixos; }; in
          {
            nixosConfigurations.${host.name} = sys;
            deploy.nodes.${host.name} = { hostname = deploy.address; sshUser = deploy.user; };
            ageManifest.${host.name} = lib.attrNames sys.config.age.secrets;
          };
        colmena = { host, nixos, deploy, ... }: { ${host.name} = { imports = nixos; deployment.targetHost = deploy.address; }; };
      };
      os.nixos = { os, ... }: { imports = os; };
      deploy.reduce = one;
    };
  };
}
