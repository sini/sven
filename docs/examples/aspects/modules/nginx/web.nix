# One aspect, two files. `at` is the union of both files.
{ sven, ... }:
{
  sven.aspects.nginx = {
    at = sven.host.web;
    packages = "nginx";
  };
}
