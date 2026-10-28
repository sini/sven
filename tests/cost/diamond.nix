# k levels of aspect-ref diamonds: x_i holds where l_i and r_i hold, both read x_(i-1). Without a memo: 2^k reads.
{
  k ? 30,
}:
let
  b = builtins;
  sven = (import ../../default.nix).lib;
in
(sven.eval (
  { sven, ... }:
  {
    sven.kinds.top.spawns.host = _: sven.host;
    sven.kinds.host = { };
    sven.top.t = { };
    sven.host.h = { };
    sven.aspects = {
      x0.at = sven.kinds.host;
    }
    // b.listToAttrs (
      b.concatMap (
        i:
        let
          p = "x${toString (i - 1)}";
        in
        [
          {
            name = "l${toString i}";
            value.at = sven.aspects.${p};
          }
          {
            name = "r${toString i}";
            value.at = sven.aspects.${p};
          }
          {
            name = "x${toString i}";
            value.at = sven.lib.all [
              sven.aspects."l${toString i}"
              sven.aspects."r${toString i}"
            ];
          }
        ]
      ) (b.genList (i: i + 1) k)
    );
  }
)).active."x${toString k}"."top:t/host:h"
