# A kind declares the fields of its instances. Every field has a type.
{ sven, lib, ... }:
{
  sven.kinds.host.fields = {
    addr = lib.types.str;
    cores = lib.types.int;
  };
}
