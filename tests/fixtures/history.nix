# A fleet that changes between two commits: the history oracle reads it at both revisions.
{ sven, ... }:
{
  sven.kinds.top.spawns.host = _: sven.host;
  sven.kinds.host.fields = { port = sven.lib.is builtins.isInt; validTo = sven.lib.opt (sven.lib.is builtins.isString) "9999-12-31"; };
  sven.top.t = { };
  sven.host.a = { port = 2222; validTo = "2026-12-01"; };
  sven.host.b.port = 80;
}
