# A component: it reads sources (the tree, the sinks) and writes sinks. It gives 0 to n elements.
{ sven, ... }:
{
  sven.aspects.vm-network = {
    at = sven.lib.has sven.kinds.guest; # every host with a guest
    cycle = { tree, ... }: {
      tree = [ { category = "vms"; children = sven.kinds.guest; } ]; # a request: the guest children
      bridges = map (g: "br-${g.name}") (builtins.head (tree.select "vms")); # one element per guest
      errors = [ ];
    };
  };
}
