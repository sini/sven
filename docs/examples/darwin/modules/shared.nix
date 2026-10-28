# Written once, for every machine: options that NixOS and nix-darwin share.
{ sven, ... }:
{
  sven.aspects.shared = {
    at = [
      sven.kinds.host
      sven.kinds.mac
    ];
    os =
      { scope, pkgs, ... }:
      {
        networking.hostName = scope.name;
        environment.systemPackages = [ pkgs.git ];
        nix.settings.experimental-features = [
          "nix-command"
          "flakes"
        ];
      };
  };
}
