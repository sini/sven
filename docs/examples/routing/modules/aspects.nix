{ sven, ... }:
{
  sven.aspects.accounts = {
    at = [
      sven.kinds.user
      sven.kinds.home
    ];
    os = { scope, ... }: "account ${scope.name}";
  };
  sven.aspects.records = {
    at = sven.kinds.host;
    dns = { host, ... }: "${host.name} A";
  };
}
