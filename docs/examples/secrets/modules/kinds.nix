# A secret is data: nothing spawns it. A host's `secrets` sink only takes secret refs.
{ sven, lib, ... }:
{
  sven.kinds.fleet = {
    spawns.host = _: sven.host;
    sinks.out.reduce = sven.lib.reduce.merge;
  };
  sven.kinds.secret.fields = {
    file = lib.types.str; # the encrypted file in the repo
    owners = sven.lib.is lib.isList; # host refs
  };
  sven.kinds.host.sinks.secrets = {
    reduce = sven.lib.reduce.set;
    of = sven.kinds.secret;
    # the plan a secrets tool reads: agenix, sops-nix, or your own
    out =
      { host, secrets, ... }:
      {
        secretsPlan.${host.name} = map (s: {
          inherit (s) name file;
          path = "/run/secrets/${s.name}";
        }) secrets;
      };
  };

  sven.fleet.main = { };
  sven.flake = { out, ... }: out;
}
