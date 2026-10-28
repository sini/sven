# A role is an aspect whose `at` is a fact test. Roles build on roles.
{ sven, lib, ... }:
let
  inherit (sven.lib) all not;
in
{
  sven.aspects = {
    server.at = s: (s.form or null) == "server";
    workstation.at = s: lib.elem (s.form or null) [ "laptop" "desktop" ];
    laptop.at = s: (s.form or null) == "laptop";
    nvidia.at = s: (s.gpu or null) == "nvidia";
    ci-runner.at = s: lib.elem "ci-runner" (s.labels or [ ]);
    gaming.at = all [ sven.aspects.workstation sven.aspects.nvidia (not sven.aspects.laptop) ];
    backups.at = [ sven.aspects.server sven.aspects.workstation ];
  };
}
