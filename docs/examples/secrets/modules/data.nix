{ sven, ... }:
{
  sven.host.web = { };
  sven.host.db = { };
  sven.secret.tls = {
    file = "secrets/tls.age";
    owners = [ sven.host.web ];
  };
  sven.secret.db-password = {
    file = "secrets/db-password.age";
    owners = [
      sven.host.web
      sven.host.db
    ];
  };
  sven.secret.old-token = {
    file = "secrets/old-token.age";
    owners = [ ];
  };
}
