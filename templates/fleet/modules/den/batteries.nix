# Den batteries are ordinary aspects here: hostname is in features/base.nix, define-user in user-account, primary-user in sini/users.nix.
{ sven, lib, ... }:
let
  inherit (sven.lib) all within has;
in
{
  sven.kinds.user.fields.shell = sven.lib.opt (sven.helpers.enum [ "bash" "zsh" "fish" ]) "bash";
  sven.user.bob.shell = "fish";
  sven.aspects.user-shell = { # user-shell: the user's shell, enabled on the machine
    at = all [ sven.kinds.user (within sven.helpers.linux) ];
    os = { user, pkgs, ... }: { programs.${user.shell}.enable = lib.mkIf (user.shell != "bash") true; users.users.${user.name}.shell = pkgs.${user.shell}; };
  };
  sven.aspects.insecure = { at = sven.host.stage; os.nixpkgs.config.permittedInsecurePackages = [ "olm-3.2.16" ]; };
  sven.aspects.tty-autologin = { at = all [ sven.user.bob (within sven.kinds.guest) ]; os = { user, ... }: { services.getty.autologinUser = user.name; }; };
  sven.aspects.global-pkgs = { # use-global-pkgs: only where home-manager has users
    at = all [ sven.helpers.machines (has sven.kinds.user) ];
    os.home-manager = { useGlobalPkgs = true; useUserPackages = true; };
  };
}
