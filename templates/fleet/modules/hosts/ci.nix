# ci is a guest on stage, built with the stable channel while stage uses edge.
{ sven, ... }:
{
  sven.guest.ci = { environment = sven.environment.staging; channel = sven.channel.stable; system = sven.system.x86_64-linux; addr = "10.0.2.20"; on = sven.host.stage; };
}
