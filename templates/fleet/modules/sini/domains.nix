# Recursive kinds: domains under domains. `parent` is a scope key, so the field is `under`.
{ sven, lib, ... }:
let
  inherit (sven.lib) maybe opt;
in
{
  sven.kinds.fleet.spawns.domain = _: lib.filterAttrs (_: d: d.under == null) sven.domain;
  sven.kinds.domain = {
    fields = {
      under = maybe sven.kinds.domain;
      mail.dkim = opt (sven.helpers.listOf lib.types.str) [ ];
      mail.enable = opt lib.types.bool false;
    };
    spawns.domain = s: lib.filterAttrs (_: d: d.under != null && sven.lib.same d.under s) sven.domain;
  };
  sven.kinds.fleet.sinks = {
    dns-records.reduce = sven.lib.reduce.entries;
    certificate-domains.of = lib.types.str;
  };
  sven.domain."example.org".mail.enable = true;
  sven.domain."api.example.org".under = sven.domain."example.org";
  sven.domain."v1.api.example.org".under = sven.domain."api.example.org";
  sven.aspects.domain-mail = {
    at = sven.lib.all [
      sven.kinds.domain
      (s: s.mail.enable)
    ];
    dns-records =
      { domain, ... }:
      {
        name = domain.name;
        type = "MX";
        content = "mail.protonmail.ch";
      };
  };
  sven.aspects.domain-tls = {
    at = sven.kinds.domain;
    certificate-domains = { domain, ... }: domain.name;
  };
}
