# `parent`: alice's syncthing devices are her other parents. `holds` inside content: the tray on desktops.
{ sven, lib, ... }:
{
  sven.aspects.sync = {
    at = sven.kinds.user;
    persist = { user, ... }: "/home/${user.name}/.local/state/syncthing";
    homeManager =
      { user, scope, ... }:
      {
        services.syncthing.enable = true;
        services.syncthing.settings.devices =
          lib.genAttrs
            (map (s: s.parent.name) (lib.filter (s: s.path != scope.path) (sven.lib.scopesOf user)))
            (n: {
              id = builtins.hashString "sha256" n;
            });
        services.syncthing.tray.enable = sven.lib.holds sven.aspects.desktop scope.parent;
      };
  };
}
