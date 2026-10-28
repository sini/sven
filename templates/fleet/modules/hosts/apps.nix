# Four app hosts to compare shared pkgs: app-1..3 reuse one pkgs (app-1 leads), app-4 builds its own.
{ sven, lib, ... }:
{
  sven.host = lib.genAttrs [ "app-1" "app-2" "app-3" "app-4" ] (n: {
    environment = sven.environment.lab;
    channel = sven.channel.stable;
    system = sven.system.x86_64-linux;
    addr = "10.0.9.${lib.removePrefix "app-" n}";
    sharedPkgs = n != "app-4";
  });
  # docs off: with docs on, a shared pkgs changes the manual, manpage and help derivations (evalmodules-research.md)
  sven.aspects.lab-no-docs = { at = sven.lib.all [ sven.kinds.host (sven.lib.within sven.environment.lab) ]; nixos.documentation = { enable = false; nixos.enable = false; man.enable = false; }; };
}
