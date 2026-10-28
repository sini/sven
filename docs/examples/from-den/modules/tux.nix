# The tux aspect. `includes` becomes `at` on the included aspects.
{ sven, ... }:
{
  sven.user.tux.hosts = [ sven.host.igloo ];
  sven.aspects.define-user.at = sven.user.tux;
  sven.aspects.primary-user.at = sven.user.tux;
  sven.aspects.tux = {
    at = sven.user.tux;
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.htop ];
      };
  };
}
