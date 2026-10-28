# Trust graph: the filter lives with the reader.
{ sven, lib, ... }:
let
  trusts = e: user: !(sven.lib.same e.from user);
in
{
  sven.kinds.fleet.sinks.xmsg-nodes.reduce = sven.lib.reduce.entries;
  sven.aspects.xmsg = {
    at = sven.kinds.user;
    xmsg-nodes = { user, ... }: user.name;
    homeManager =
      { xmsg-nodes, user, ... }:
      {
        home.file.".xmsg-peers".text = builtins.toJSON (
          lib.unique (map (e: e.value) (lib.filter (e: trusts e user) xmsg-nodes))
        );
      };
  };
}
