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
        colmena = { host, scope, nixos, deploy, tags, ... }: { # tags: a source; roles: active aspects (hasAspect = holds)
          ${host.name} = { imports = nixos; deployment = { targetHost = deploy.address; tags = [ host.environment.name ] ++ tags ++ lib.filter (n: sven.lib.holds sven.aspects."role-${n}" scope) [ "server" "workstation" "laptop" ]; }; };
        };
      };
      os.nixos = { os, ... }: { imports = os; };
      deploy.reduce = one;
    };
  };
}
