# The routing graph as a knowledge pack: sorted N-Triples with a sha256. Same fleet, same hash, any file order.
{ sven, ... }:
{
  sven.aspects.pack = {
    at = sven.kinds.fleet;
    out.rdfPack = removeAttrs (sven.lib.rdf.share {
      graph = sven.lib.graph;
      active = { };
      errors = [ ];
    }) [ "ntriples" ];
  };
}
