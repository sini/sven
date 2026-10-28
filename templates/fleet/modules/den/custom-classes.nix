# Den custom classes and chained forwards: a user `git` sink forwards into homeManager, which forwards into the machine's os.
# A user `maid` sink (Den hjem / maid) writes straight into the NixOS user, with no home-manager.
{ sven, lib, ... }:
{
  sven.kinds.user.sinks.git = { reduce = sven.lib.reduce.merge; homeManager = { git, ... }: { options, ... }: { programs.git = { enable = true; } // (if options.programs.git ? settings then { settings = git; } else { extraConfig = git; }); }; }; # HM 25.05: extraConfig; newer: settings
  sven.kinds.user.sinks.maid = {
    at = sven.lib.all [ (sven.lib.within sven.helpers.linux) (s: lib.elem "maid" s.classes) ];   # only users whose `classes` list it (#26)
    os = { user, maid, ... }: { systemd.tmpfiles.rules = lib.mapAttrsToList (p: text: "f+ /home/${user.name}/${p} 0644 ${user.name} users - ${text}") (lib.foldl' (a: b: a // b) { } maid); };
  };
  sven.aspects.git-identity = { at = sven.kinds.user; git = { user, ... }: { user.name = user.name; user.email = "${user.name}@example.org"; }; };
  sven.aspects.git-defaults = { at = sven.kinds.user; git.init.defaultBranch = "main"; };
  sven.aspects.dotfile = { at = sven.user.bob; maid.".hushlogin" = ""; };
}
