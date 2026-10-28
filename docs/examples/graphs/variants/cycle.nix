# db now depends on lb: a cycle.
{ sven, ... }:
{
  sven.host.db.dependsOn = [ sven.host.lb ];
}
