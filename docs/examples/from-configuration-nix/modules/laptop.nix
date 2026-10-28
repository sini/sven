# The machine and its people: data, not configuration.
{ sven, ... }:
{
  sven.host.laptop = { };
  sven.user.alice = {
    hosts = [ sven.host.laptop ];
    groups = [ "wheel" ];
  };
}
