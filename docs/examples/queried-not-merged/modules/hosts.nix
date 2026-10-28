{ sven, ... }:
{
  sven.kinds.host.fields.environment = sven.kinds.environment;
  sven.environment.prod.settings.zfs.arcMax = 8;

  sven.host.nas = {
    environment = sven.environment.prod;
    settings.zfs.arcMax = 32;
  };
  sven.host.node = {
    environment = sven.environment.prod;
    settings.k3s.role = "server";
  };
}
