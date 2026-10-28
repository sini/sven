# A secret by name, not by ref: `of` refuses it.
{ sven, ... }:
{
  sven.aspects.shortcut = { at = sven.host.db; secrets = "tls"; };
}
