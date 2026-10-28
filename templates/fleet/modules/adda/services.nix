# adda: service aspects give their domains; the caddy host reads them as virtual hosts. The fleet also exports flake templates.
{ sven, lib, ... }:
{
  sven.kinds.host.sinks.service-domains = {
    of = lib.types.str;
    reduce = sven.lib.reduce.set;
  };
  sven.aspects.grafana = {
    at = sven.host.lb;
    service-domains = "grafana.example.org";
    nixos.services.grafana.enable = true;
  };
  sven.aspects.status-page = {
    at = sven.host.lb;
    service-domains = "status.example.org";
  };
  sven.aspects.caddy = {
    at = sven.host.lb;
    nixos =
      { service-domains, ... }:
      {
        services.caddy.enable = true;
        services.caddy.virtualHosts = lib.genAttrs service-domains (d: {
          extraConfig = "reverse_proxy localhost:3000";
        });
      };
  };
  sven.kinds.fleet.sinks.templates = {
    reduce = sven.lib.reduce.merge;
    out =
      { templates, ... }:
      {
        inherit templates;
      };
  };
  sven.aspects.fleet-template = {
    at = sven.fleet.main;
    templates.default = {
      path = ../..;
      description = "A sven fleet";
    };
  };
}
