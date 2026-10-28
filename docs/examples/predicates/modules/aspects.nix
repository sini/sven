{ sven, ... }:
let
  inherit (sven.lib) all not within has;
in
{
  sven.aspects = {
    builder.at = s: (s.cores or 0) >= 16;                       # a function of the scope: a fact test
    cuda.at = all [ sven.kinds.host (s: s.gpu) ];               # all of a list
    tiny.at = all [ sven.kinds.host (not sven.aspects.builder) ]; # an aspect ref, negated
    vm-tools.at = within sven.aspects.cuda;                     # a proper ancestor holds
    vm-host.at = has sven.kinds.guest;                          # a child holds
    monitored.at = [ sven.host.small sven.aspects.vm-host ];    # a list is "any"
  };
}
