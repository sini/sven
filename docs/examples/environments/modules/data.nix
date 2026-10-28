{ sven, ... }:
{
  sven.group = { admins = { }; devs = { }; };
  sven.environment.prod = { domain = "example.com"; grants = [ sven.group.admins ]; settings.timeZone = "UTC"; };
  sven.environment.staging = { domain = "staging.example.com"; base = sven.environment.prod; grants = [ sven.group.admins sven.group.devs ]; };
  sven.host.web = { environment = sven.environment.prod; };
  sven.host.web-next = { environment = sven.environment.staging; settings.timeZone = "Europe/Berlin"; };
  sven.host.api-next = { environment = sven.environment.staging; };
  sven.user.ana.groups = [ sven.group.admins ];
  sven.user.dev.groups = [ sven.group.devs ];
}
