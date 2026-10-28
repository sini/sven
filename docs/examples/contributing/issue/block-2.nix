# The problem: two aspects give an admin. I expected the second to win.
{ sven, ... }:
{
  sven.aspects.ops = { at = sven.kinds.host; admin = "ana"; };
  sven.aspects.dev = { at = sven.host.web; admin = "bo"; };
}
