# Den #525 (a policy gated on hasAspect that creates structure): a backup job scope exists under every host where the
# `role-server` aspect holds. Structure reads presence at the parent; presence never reads the structure it makes.
{ sven, lib, ... }:
{
  sven.kinds.host.spawns.backup =
    s: lib.optionalAttrs (sven.lib.holds sven.aspects.role-server s) { nightly = { }; };
  sven.kinds.backup.sinks.nixos.nixos =
    {
      backup,
      host,
      nixos,
      ...
    }:
    {
      services.restic.backups.${backup.name} = {
        paths = lib.concatMap (m: m.paths or [ ]) nixos;
        repository = "sftp:backup@10.0.9.9:/srv/${host.name}";
        passwordFile = "/run/agenix/restic";
      };
    };
  sven.aspects.backup-persist = {
    at = sven.kinds.backup;
    nixos =
      { host, ... }:
      {
        paths = [
          "/persist"
          "/etc/${host.name}"
        ];
      };
  };
}
