# age-secrets: one sink name on three kinds. A body that reads `config` is a module element. Unfree names collapse in a set.
{ sven, lib, ... }:
{
  sven.kinds.user.sinks.age-secrets.homeManager = { age-secrets, ... }: { imports = age-secrets; };
  sven.kinds.cluster.sinks.age-secrets.k8s-manifests = { age-secrets, ... }: { imports = age-secrets; };
  sven.kinds.host.sinks.age-secrets.nixos = { age-secrets, ... }: { imports = age-secrets; };
  sven.aspects.attic = {
    at = sven.host.lb;
    age-secrets = { config, ... }: { age.secrets.attic-env = { file = ../../secrets/attic.age; path = "/run/agenix/${config.networking.hostName}-attic"; }; };
  };
  sven.kinds.host.sinks.unfree = {
    of = lib.types.str;
    reduce = sven.lib.reduce.set;
    os = { unfree, ... }: { nixpkgs.config.allowUnfreePredicate = p: lib.elem (lib.getName p) unfree; };
  };
  sven.aspects.terraform-cli = { at = sven.host.stage; unfree = "terraform"; nixos = { pkgs, ... }: { environment.systemPackages = [ pkgs.terraform ]; }; };
}
