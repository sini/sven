# CI from the fleet itself: every buildable config gives one job. `ci.json` is a generated file, so its check fails when the infra changes and nobody regenerated it.
{ sven, lib, ... }:
let
  job = system: name: attr: { ${name} = { inherit name attr system; }; };
in
{
  sven.kinds.fleet.sinks.ci = {
    reduce = sven.lib.reduce.merge;
    out =
      { ci, ... }:
      {
        ci.matrix = lib.attrValues ci;
      };
  };
  sven.aspects.ci-host = {
    at = sven.lib.all [
      sven.kinds.host
      (s: !s.minimal)
    ];
    ci =
      { host, ... }:
      job host.system.name host.name "nixosConfigurations.${host.name}.config.system.build.toplevel";
  };
  sven.aspects.ci-mac = {
    at = sven.kinds.mac;
    ci =
      { mac, ... }:
      job mac.system.name mac.name "darwinConfigurations.${mac.name}.config.system.build.toplevel";
  };
  sven.aspects.ci-home = {
    at = sven.kinds.home;
    ci =
      { home, ... }:
      job home.system.name home.name "homeConfigurations.\"${home.name}\".activationPackage";
  };
  sven.aspects.ci-shell = {
    at = sven.kinds.system;
    ci = { system, ... }: job system.name "devshell-${system.name}" "devShells.${system.name}.default";
  };
  sven.aspects.ci-file = {
    at = sven.system.x86_64-linux;
    files =
      { ci, ... }:
      {
        files.file."ci.json".text = builtins.toJSON (lib.attrValues ci) + "\n";
      };
  };
}
