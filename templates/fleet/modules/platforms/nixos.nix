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
        # Shared pkgs: hosts with `sharedPkgs` on one (channel, system) reuse the pkgs of the first of them (the leader)
        # through nixpkgs' readOnlyPkgs, so nixpkgs is imported once per group. `nixosConfigurationsOwnPkgs` keeps each
        # follower's build with its own pkgs, so a check can prove both give the same toplevel drvPath.
        out = { host, nixos, deploy, out, ... }:
          let
            np = host.channel.nixpkgs;
            build = ms: np.lib.nixosSystem { system = host.system.name; modules = ms; };
            group = lib.sort (a: b: a < b) (lib.attrNames (lib.filterAttrs (_: h: h ? addr && h.sharedPkgs && same h.channel host.channel && same h.system host.system) sven.host));
            leader = lib.head group;
            follower = host.sharedPkgs && leader != host.name;
            shared = out.nixosConfigurations.${leader}.pkgs;
            readOnly = [
              np.nixosModules.readOnlyPkgs
              { options.nixpkgs.system = np.lib.mkOption { internal = true; }; }
              { nixpkgs.pkgs = shared; nixpkgs.overlays = np.lib.mkForce shared.overlays; nixpkgs.config = np.lib.mkForce shared.config; }
            ];
            sys = build (nixos ++ lib.optionals follower readOnly);
          in
          {
            nixosConfigurations.${host.name} = sys;
            nixosConfigurationsOwnPkgs = lib.optionalAttrs follower { ${host.name} = build nixos; };
            sharedPkgs = lib.optionalAttrs host.sharedPkgs { ${host.name} = { inherit leader; follower = follower; }; };
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
