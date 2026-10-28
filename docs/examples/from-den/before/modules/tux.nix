{ den, ... }:
{
  den.aspects.tux = {
    includes = [
      den.batteries.define-user
      den.batteries.primary-user
    ];
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.htop ];
      };
  };
}
