# den-hoag A8/A14/A10: aspect settings in layers with authority, and an aspect that projects settings onto other aspects.
# In sven a layer is an element, and the merge order is a reduce strategy you write (a "discipline" is a function).
{ sven, lib, ... }:
let
  # authority: each element is { rank; set; }. Higher rank wins per key (Leijen `shadow`); equal ranks must agree.
  layers =
    es:
    let
      sorted = lib.sort (a: b: a.value.rank < b.value.rank) es;
    in
    {
      value = lib.foldl' (acc: e: lib.recursiveUpdate acc e.value.set) { } sorted;
      errors = lib.concatLists (
        lib.imap0 (
          i: a:
          lib.concatMap (
            b:
            lib.optional
              (
                a.value.rank == b.value.rank
                && lib.intersectAttrs a.value.set b.value.set != lib.intersectAttrs b.value.set a.value.set
              )
              {
                error = "aspect-settings: two layers of rank ${toString a.value.rank} disagree";
                from = a.from.id;
              }
          ) (lib.drop (i + 1) es)
        ) es
      );
    };
  rank = {
    schema = 0;
    contains = 1;
    slice = 2;
    policy = 3;
  };
in
{
  sven.kinds.host.sinks.aspect-settings.reduce = layers;
  sven.aspects.nginx.aspect-settings = {
    rank = rank.schema;
    set.nginx = {
      workers = 1;
      gzip = true;
    };
  }; # the aspect's own default
  sven.aspects.env-tuning = {
    at = sven.lib.all [
      sven.kinds.host
      (sven.lib.within sven.environment.prod)
    ];
    aspect-settings = {
      rank = rank.contains;
      set.nginx.workers = 4;
    };
  };
  sven.aspects.web1-tuning = {
    at = sven.host.web-1;
    aspect-settings = {
      rank = rank.slice;
      set.nginx.workers = 8;
    };
  };
  # a projector: onto every aspect present here that declares settings (its own schema-rank layer)
  sven.aspects.no-gzip = {
    at = sven.host.stage;
    aspect-settings =
      { scope, ... }:
      {
        rank = rank.policy;
        set =
          lib.genAttrs
            (lib.filter (
              n:
              (sven.aspects.${n}.aspect-settings.rank or null) == rank.schema
              && sven.lib.holds sven.aspects.${n} scope
            ) (lib.attrNames sven.aspects))
            (_: {
              gzip = false;
            });
      };
  };
  sven.aspects.nginx-tuned = {
    # the narrow accessor: present (holds) + settings (the sink value)
    at = sven.aspects.nginx;
    nixos =
      { aspect-settings, ... }:
      {
        services.nginx.appendConfig = "worker_processes ${toString aspect-settings.nginx.workers};";
        services.nginx.recommendedGzipSettings = aspect-settings.nginx.gzip;
      };
  };
}
