# A change, as an agent proposes it: a lab host that uses the prod database.
{ sven, ... }:
{
  sven.host.api = {
    env = sven.env.lab;
    addr = "10.0.1.2";
    db = sven.host.db;
  };
}
