{ sven, ... }:
{
  sven.environment.prod.domain = "example.com";
  sven.environment.lab.domain = "lab.example.com";

  sven.host.web = {
    environment = sven.environment.prod;
    backup = sven.host.db;
  };
  sven.host.db = {
    environment = sven.environment.prod;
    backup = sven.host.web;
  }; # refs can point both ways
  sven.host.test.environment = sven.environment.lab;
}
