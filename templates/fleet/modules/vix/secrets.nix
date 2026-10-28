# vix: secrets are a data kind (no scopes). Features give the secrets they need on the user's `secrets` sink.
{ sven, lib, ... }:
{
  sven.kinds.secret.fields.sopsKey = lib.types.str;
  sven.secret.gh-token.sopsKey = "github_token";
  sven.secret.gpg-key.sopsKey = "gpg_key";
  sven.kinds.user.sinks.secrets = {
    of = sven.kinds.secret;
    reduce = sven.lib.reduce.set;
    homeManager =
      { secrets, ... }:
      {
        home.file.".secrets".text = lib.concatMapStringsSep "\n" (s: s.sopsKey) secrets;
      };
  };
  sven.aspects.gh = {
    at = sven.kinds.user;
    secrets = sven.secret.gh-token;
  };
  sven.aspects.gpg = {
    at = sven.user.bob;
    secrets = sven.secret.gpg-key;
  };
}
