# Content gets the trust of the files that declare it: files under agent/ are written by agents.
{ ... }:
{
  sven.labels."agent/" = { trust = 1; };
}
