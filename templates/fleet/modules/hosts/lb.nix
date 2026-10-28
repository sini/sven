{ sven, ... }:
{
  sven.host.lb = {
    environment = sven.environment.prod;
    channel = sven.channel.stable;
    system = sven.system.x86_64-linux;
    addr = "10.0.1.1";
    sharedPkgs = true;
  };
}
