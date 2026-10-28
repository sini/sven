{ sven, ... }:
{
  sven.environment.prod.domain = "example.com";
  sven.host.web.environment = sven.environment.prod;
  sven.host.db.environment = sven.environment.prod;
  sven.aspects.nginx = { at = sven.host.web; services = "nginx"; };
}
