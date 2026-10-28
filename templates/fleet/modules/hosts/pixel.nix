{ sven, ... }:
{
  sven.phone.pixel = {
    environment = sven.environment.staging;
    channel = sven.channel.stable;
    system = sven.system.aarch64-linux;
  };
}
