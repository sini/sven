# Groups are data: nothing spawns them, so they have no scopes. Groups nest through `members`.
{ sven, ... }:
{
  sven.kinds.group.fields.members = sven.lib.opt (sven.helpers.listOf sven.kinds.group) [ ];
  sven.group = { ops = { }; deploy = { }; admin.members = [ sven.group.ops ]; };
}
