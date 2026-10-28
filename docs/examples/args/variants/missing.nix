# `cluster` without a default: no answer at lb, so the element is not given.
{ sven, ... }:
{
  sven.aspects.cluster-name = {
    at = sven.host.lb;
    proxy = { cluster, ... }: cluster.name;
  };
}
