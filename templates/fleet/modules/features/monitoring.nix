# Typed elements (`of`): each replica gives one scrape job; lb reads the pool.
{ sven, ... }:
{
  sven.aspects.replica-scrape = { at = sven.kinds.replica; scrape = { replica, ... }: { job = replica.name; target = "${replica.db.zone}.${replica.region.zone}:9090"; }; };
  sven.aspects.monitoring = {
    at = sven.host.lb;
    nixos = { scrape, ... }: { services.prometheus.enable = true; services.prometheus.scrapeConfigs = map (j: { job_name = j.job; static_configs = [ { targets = [ j.target ]; } ]; }) scrape; };
  };
}
