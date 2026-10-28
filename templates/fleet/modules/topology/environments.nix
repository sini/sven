# Environments own hosts, macs and phones (parent-side spawns) and two pools.
{ sven, lib, inputs, ... }:
let
  inherit (sven.helpers) listOf inEnv enum;
  inherit (sven.lib) opt maybe;
in
{
  sven.kinds.environment = {
    fields = {
      grants = listOf sven.kinds.group;
      edge = opt lib.types.bool false;
      base = maybe sven.kinds.environment;
      settings.kernel.channel = maybe (enum [ "lts" "latest" ]);
    };
    spawns = { host = inEnv sven.host; mac = inEnv sven.mac; phone = inEnv sven.phone; };
    sinks.backends.of = lib.types.str; # lb reads it
    sinks.terraform = { # a conditional receiver
      at = s: s.edge;
      out = { terraform, ... }: { terraformConfigurations.dns = inputs.terranix.lib.terranixConfiguration { system = "x86_64-linux"; modules = terraform; }; };
    };
  };
  sven.environment.prod = { grants = [ sven.group.admin sven.group.sso ]; edge = true; settings.kernel.channel = "lts"; };
  sven.environment.staging = { grants = [ sven.group.admin sven.group.deploy ]; base = sven.environment.prod; };
  sven.environment.lab = { grants = [ ]; };   # apps for the shared-pkgs comparison: no users, no edge
}
