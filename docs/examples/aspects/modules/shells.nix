{ sven, ... }:
{
  # active at hosts and at users; static content lands once at each receiver
  sven.aspects.zsh = {
    at = [ sven.kinds.host sven.kinds.user ];
    packages = "zsh";
  };
  # content that names the scope lands once per scope
  sven.aspects.dotfiles = {
    at = sven.kinds.user;
    packages = { user, ... }: "dotfiles-${user.name}";
  };
}
