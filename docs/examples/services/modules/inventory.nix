{ sven, ... }:
{
  sven.host.nas.addr = "10.0.0.10";
  sven.host.web.addr = "10.0.0.1";
  sven.host.db.addr = "10.0.0.2";
  sven.instance.backup.roles = {
    server = [ sven.host.nas ];
    client = [
      sven.host.web
      sven.host.db
    ];
  };
}
