# Each feature declares its own setting, at its own path, in its own file.
{ sven, lib, ... }:
{
  sven.kinds.host.fields.settings.zfs.arcMax = sven.lib.maybe lib.types.int;
  sven.kinds.environment.fields.settings.zfs.arcMax = sven.lib.maybe lib.types.int;
}
