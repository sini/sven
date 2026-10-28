# Phones: nix-on-droid. Only phone users live here; their homes go to the droid config.
{
  sven,
  lib,
  inputs,
  ...
}:
{
  sven.kinds.phone = {
    fields = { inherit (sven.kinds.machine.fields) environment channel system; };
    spawns.user = _: lib.filterAttrs (_: u: u.phone) sven.user;
    sinks.droid.out =
      { phone, droid, ... }:
      {
        nixOnDroidConfigurations.${phone.name} = inputs.nix-on-droid.lib.nixOnDroidConfiguration {
          pkgs = sven.helpers.pkgsOf phone;
          modules = droid;
        };
      };
    sinks.homeManager.droid =
      { homeManager, ... }:
      {
        home-manager.config.imports = homeManager;
      };
  };
}
