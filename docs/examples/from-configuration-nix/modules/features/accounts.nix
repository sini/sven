# Each user gives its account. A user has no `nixos` sink, so the account goes up to the host.
{ sven, ... }:
{
  sven.aspects.account = {
    at = sven.kinds.user;
    nixos = { user, ... }: { users.users.${user.name} = { isNormalUser = true; extraGroups = user.groups; }; };
  };
}
