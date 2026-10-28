# Users and standalone homes. A user's homeManager goes to its machine's os, or up to a phone or home.
{ sven, lib, ... }:
let
  inherit (sven.lib) within opt all not;
  inherit (sven.helpers) machines pkgsOf flatten listOf;
in
{
  sven.kinds.home = {
    fields = { user = sven.kinds.user; channel = sven.kinds.channel; system = sven.kinds.system; };
    spawns.user = s: { ${s.user.name} = s.user; };
    sinks.homeManager.out = { home, homeManager, ... }: {
      homeConfigurations.${home.name} = home.channel.home-manager.lib.homeManagerConfiguration { pkgs = pkgsOf home; modules = homeManager; };
    };
  };
  sven.kinds.user = {
    fields = { groups = listOf sven.kinds.group; phone = opt lib.types.bool false; };
    sinks = {
      homeManager = { at = all [ (within machines) (not (within sven.kinds.home)) ]; os = { user, homeManager, ... }: { home-manager.users.${user.name}.imports = homeManager; }; };
      homeDarwin = { at = within sven.kinds.mac; homeManager = { homeDarwin, ... }: { imports = homeDarwin; }; };
      account = { at = within machines; os = { user, account, ... }: { pkgs, ... }@a: { users.users.${user.name} = flatten a account; }; };
    };
  };
}
