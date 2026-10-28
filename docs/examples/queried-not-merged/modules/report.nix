# `cascade path xs`: the first non-null value along a list, in your order.
{ sven, ... }:
{
  sven.aspects.report = {
    at = sven.kinds.host;
    report =
      { host, ... }:
      {
        ${host.name} = {
          arcMax = sven.lib.cascade [ "settings" "zfs" "arcMax" ] [ host host.environment ];
          k3s = host.settings.k3s.role;
        };
      };
  };
}
