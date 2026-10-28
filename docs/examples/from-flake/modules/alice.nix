# A user: an account on each of her hosts, and her home.
{ sven, ... }:
{
  sven.user.alice.hosts = [ sven.host.web sven.host.desk ];
  sven.aspects.alice = {
    at = sven.user.alice;
    nixos = { user, ... }: { users.users.${user.name} = { isNormalUser = true; extraGroups = [ "wheel" ]; }; };
    homeManager = {
      programs.git = { enable = true; userName = "Alice"; };
      home.stateVersion = "25.05";
    };
  };
}
