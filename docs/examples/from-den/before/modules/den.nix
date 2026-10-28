{ inputs, lib, ... }:
{
  imports = [ inputs.den.flakeModule ];
  den.schema.user.classes = lib.mkDefault [ "homeManager" ];
  den.default.nixos.system.stateVersion = "25.05";
  den.default.homeManager.home.stateVersion = "25.05";
  den.hosts.x86_64-linux.igloo.users.tux = { };
}
