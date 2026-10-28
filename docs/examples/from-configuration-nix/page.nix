{
  title = "From configuration.nix";
  description = "Move a single /etc/nixos/configuration.nix to sven, and build the same system.";
  section = "migrate";
  order = 1;
  badge = "start here";

  body = { docs, ... }: [
    ''
      You have one machine and one `configuration.nix`. This page moves it to sven. The result builds the
      **same system**: the docs check that both give one toplevel `drvPath`.
    ''
    (docs.tabs [
      { label = "Before: configuration.nix"; body = docs.file "before/configuration.nix"; }
      { label = "hardware-configuration.nix"; body = docs.file "before/hardware-configuration.nix"; }
    ])
    ''
      ## What changes

      A `configuration.nix` mixes three things: data (the host name, the users), features (ssh, tools),
      and generated hardware. sven keeps them apart:
    ''
    (docs.table [ "In configuration.nix" "In sven" ] [
      [ "`networking.hostName = \"laptop\"`" "the instance `sven.host.laptop`: the name is data" ]
      [ "`users.users.alice = …`" "the instance `sven.user.alice`, and one `account` aspect for every user" ]
      [ "`services.openssh.enable = true`" "an aspect, active at every host" ]
      [ "`imports = [ ./hardware-configuration.nix ]`" "`machines/<name>/hardware-configuration.nix`, found by name" ]
    ])
    (docs.steps [
      ''
        Get the template, and copy your two files over the ones in `machines/laptop/`:

        ${docs.sh "nix flake init -t 'github:vic/sven?dir=docs#from-configuration-nix'"}
      ''
      ''
        Declare the fleet. A host builds NixOS from its `nixos` sink. A user lives under the hosts it logs in to.

        ${docs.file "modules/fleet.nix"}
      ''
      ''
        Declare your machine and your people as data:

        ${docs.file "modules/laptop.nix"}
      ''
      ''
        Move each part of `configuration.nix` to an aspect. Each one is active at every host:

        ${docs.file "modules/features/machine.nix"}

        ${docs.file "modules/features/ssh.nix"}

        ${docs.file "modules/features/tools.nix"}
      ''
      ''
        Give accounts from user data. A user has no `nixos` sink, so the account goes up to the host:

        ${docs.file "modules/features/accounts.nix"}
      ''
      ''
        Switch:

        ${docs.sh "sudo nixos-rebuild switch --flake .#laptop"}
      ''
    ])
    (docs.tip "Do it in two steps" ''
      You do not have to split everything on day one. One aspect can give the whole old file.
      With only `modules/fleet.nix` and `modules/laptop.nix`, this builds the same system too:

      ${docs.file "variants/legacy.nix"}

      Then move one part at a time to its own aspect, and compare the `drvPath` after each move.
    '')
    ''
      ## Your second machine

      Add `sven.host.desktop = { };`, its `machines/desktop/hardware-configuration.nix`, and `sven.host.desktop`
      to the `hosts` of each user. Every aspect above is active there too. Continue with [From a flake](/migrate/from-flake/).
    ''
  ];

  e2e = { inputs, dir, flake, only, ... }: {
    step-one = (only [ "modules/fleet.nix" "modules/laptop.nix" "variants/legacy.nix" ]).flake.nixosConfigurations.laptop.config.system.build.toplevel.drvPath
      == flake.nixosConfigurations.laptop.config.system.build.toplevel.drvPath;
    same-system = (inputs.nixpkgs.lib.nixosSystem { modules = [ (dir + "/before/configuration.nix") ]; }).config.system.build.toplevel.drvPath
      == flake.nixosConfigurations.laptop.config.system.build.toplevel.drvPath;
  };
}
