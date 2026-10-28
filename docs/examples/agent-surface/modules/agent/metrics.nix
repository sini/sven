# Written by an agent.
{ sven, ... }:
{
  sven.aspects.metrics = { at = sven.kinds.host; services = "prometheus-node-exporter"; };
}
