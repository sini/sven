{ sven, ... }:
{
  sven.environment.prod = { };
  sven.environment.lab = { };
  sven.host.web.environment = sven.environment.prod;
  sven.host.db.environment = sven.environment.prod;
  sven.host.box.environment = sven.environment.lab;
  sven.user.alice.hosts = [
    sven.host.web
    sven.host.box
  ]; # one user, two scopes
  sven.user.bob.hosts = [ sven.host.db ];
}
