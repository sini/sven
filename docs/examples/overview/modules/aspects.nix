# Aspects: behavior, active where `at` holds. Each key gives one element to the sink of that name.
{ sven, ... }:
{
  sven.aspects.basics = {
    at = sven.kinds.machine; # every machine
    packages = "git";
  };
  sven.aspects.design = {
    at = sven.machine.studio; # one machine
    packages = "gimp";
  };
  sven.aspects.versioned-assets = {
    at = sven.aspects.design; # wherever `design` is active
    packages = "git"; # `set` keeps one copy
  };
}
