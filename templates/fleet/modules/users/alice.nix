{ sven, ... }:
{
  sven.user.alice = {
    groups = [ sven.group.ops ];
    phone = true;
  };
  sven.aspects.alice-account = {
    at = sven.user.alice;
    account =
      { lib, ... }:
      {
        description = lib.mkDefault "Alice";
      };
  }; # class lib, not sven's
}
