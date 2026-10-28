# An aspect reads the fields of the nearest host.
{ sven, ... }:
{
  sven.aspects.report = {
    at = sven.kinds.host;
    report = { host, ... }: { ${host.name} = "${host.addr} (${toString host.cores} cores)"; };
  };
}
