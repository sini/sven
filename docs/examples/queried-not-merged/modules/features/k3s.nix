{ sven, lib, ... }:
{
  sven.kinds.host.fields.settings.k3s.role = sven.lib.opt lib.types.str "agent";
}
