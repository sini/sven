{ sven, ... }:
{
  sven.host.stage = { environment = sven.environment.staging; channel = sven.channel.edge; system = sven.system.x86_64-linux; addr = "10.0.2.10"; };
}
