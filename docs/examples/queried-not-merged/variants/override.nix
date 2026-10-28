# A second, different answer for one leaf. Data never overrides data.
{ sven, ... }:
{
  sven.host.nas.settings.zfs.arcMax = 16;
}
