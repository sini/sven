# alice: an account on the server, and a standalone home for her laptop (any Linux, no NixOS).
{ sven, ... }:
let
  alice = sven.user.alice;
  # her own scopes, and every home that belongs to her
  hers = [
    alice
    (s: s.kind == "home" && sven.lib.same s.user alice)
  ];
in
{
  sven.user.alice.hosts = [ sven.host.server ];
  sven.home."alice@laptop" = {
    user = alice;
    system = "x86_64-linux";
  };

  sven.aspects.alice-account = {
    at = alice;
    nixos.users.users.alice = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
    };
  };
  sven.aspects.alice-home = {
    at = hers; # one home config, in NixOS and standalone
    homeManager = {
      programs.git = {
        enable = true;
        userName = "Alice";
      };
      home.stateVersion = "25.05";
    };
  };
  sven.aspects.standalone = {
    at = sven.kinds.home;
    homeManager =
      { home, ... }:
      {
        home.username = home.user.name;
        home.homeDirectory = "/home/${home.user.name}";
      };
  };
}
