# Siblings sort by the `order` sink (default 0), then by name. A parent comes before its children.
{ sven, ... }:
{
  sven.aspects.web-first = {
    at = sven.host.web;
    order = -1;
  };
}
