{ sven, ... }:
{
  sven.environment.prod.public = true;
  sven.environment.lab = { };
  sven.host.web.environment = sven.environment.prod;
  sven.host.box.environment = sven.environment.lab;
  sven.user.alice.on = sven.host.web;
  sven.home.bob.on = sven.host.web;
}
