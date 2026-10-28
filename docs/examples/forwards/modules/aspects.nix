{ sven, ... }:
{
  sven.aspects.ssh = { at = sven.kinds.host; ports = 22; };
  sven.aspects.runner = { at = sven.guest.ci; ports = 8080; config.runner.enable = true; };
}
