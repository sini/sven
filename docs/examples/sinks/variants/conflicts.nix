# Each line breaks one sink rule.
{ sven, ... }:
{
  sven.aspects.mistakes = {
    at = sven.host.web;
    admin = "bob"; # `one`: two admins
    ports = 70000; # `of`: not a port
    nginx.http.gzip = false; # `merge`: two different leaves at one path
  };
}
