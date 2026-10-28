{ sven, lib, ... }:
{
  sven.aspects.report = {
    at = sven.kinds.host;
    report = { host, ... }: {
      ${host.name} = {
        fqdn = "${host.name}.${host.environment.domain}"; # follow a ref, read its fields
        backup = if host.backup == null then null else host.backup.name;
        # `same` compares two instances by kind and name
        peers = lib.attrNames (lib.filterAttrs (n: h: n != host.name && sven.lib.same h.environment host.environment) sven.host);
      };
    };
  };
}
