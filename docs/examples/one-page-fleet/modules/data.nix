# Instances: plain data, refs between them.
{ sven, ... }:
{
  sven.fleet.main = { };
  sven.env.prod.domain = "example.com";
  sven.env.lab.domain = "lab.example.com";
  sven.host.web = {
    env = sven.env.prod;
    db = sven.host.db;
  };
  sven.host.db.env = sven.env.prod;
  sven.host.box.env = sven.env.lab;
  sven.user.ana.on = [
    sven.host.web
    sven.host.box
  ];
}
