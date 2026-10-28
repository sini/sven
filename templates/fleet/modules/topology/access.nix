# Groups are data: nothing spawns them, so they have no scopes. Groups nest through `members`.
# A label partitions groups: posix groups make unix accounts, oauth groups only make SSO identities (sini ACL).
# A machine adds its own grants, and gates (when set) narrow who comes in.
{ sven, ... }:
let
  inherit (sven.lib) opt;
  groups = opt (sven.helpers.listOf sven.kinds.group) [ ];
in
{
  sven.kinds.group.fields = { members = groups; label = opt (sven.helpers.enum [ "posix" "oauth" ]) "posix"; };
  sven.kinds.machine.fields = { grants = groups; gates = groups; };
  sven.group = { ops = { }; deploy = { }; admin.members = [ sven.group.ops ]; sso.label = "oauth"; };
}
