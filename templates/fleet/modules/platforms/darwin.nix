# macOS: the darwin sink; os fans out to darwin.
{ sven, ... }:
{
  sven.kinds.mac = {
    fields = sven.kinds.machine.fields;
    spawns.user = sven.helpers.usersOn;
    sinks.darwin.out = { mac, darwin, ... }: { darwinConfigurations.${mac.name} = mac.channel.darwin.lib.darwinSystem { system = mac.system.name; modules = darwin; }; };
    sinks.os.darwin = { os, ... }: { imports = os; };
  };
}
