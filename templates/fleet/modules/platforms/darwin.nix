# macOS: the darwin sink; os fans out to darwin.
{ sven, ... }:
{
  sven.kinds.mac = {
    fields = sven.kinds.machine.fields;
    spawns.user = sven.helpers.usersOn;
    sinks.darwin.out =
      { mac, darwin, ... }:
      {
        darwinConfigurations.${mac.name} = mac.channel.darwin.lib.darwinSystem {
          system = mac.system.name;
          modules = darwin;
        };
      };
    sinks.os.darwin =
      { os, ... }:
      {
        imports = os;
      };
  };
  # what every nix-darwin system needs: a stateVersion, and the user that user-level options (dock, defaults) apply to
  sven.aspects.darwin-base = {
    at = sven.kinds.mac;
    darwin =
      { mac, ... }:
      {
        system.stateVersion = 6;
        system.primaryUser = if mac.system-owner != null then mac.system-owner.name else "root";
      };
  };
}
