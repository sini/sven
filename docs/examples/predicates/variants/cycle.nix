# Two aspects that each hold where the other does not: no answer.
{ sven, ... }:
{
  sven.aspects.left.at = sven.lib.all [
    sven.kinds.host
    (sven.lib.not sven.aspects.right)
  ];
  sven.aspects.right.at = sven.lib.all [
    sven.kinds.host
    (sven.lib.not sven.aspects.left)
  ];
  sven.aspects.typo.at = "host";
}
