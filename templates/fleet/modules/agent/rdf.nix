# The fleet as a knowledge pack: sorted N-Triples and their sha256 (sven.lib.rdf). The same fleet gives the same hash
# on every eval and in every file order, so an agent can tell whether two revisions differ before it reads them.
# Inside the fleet only the routing graph is visible; the full pack (active aspects, errors) is `sven.lib.rdf.share r`
# over the eval result, as query.nix gives it. A store such as quipu can import the triples in a separate, approved step.
{ sven, ... }:
{
  sven.aspects.rdf-pack = {
    at = sven.fleet.main;
    out = { ... }: { rdfPack = removeAttrs (sven.lib.rdf.share { graph = sven.lib.graph; active = { }; errors = [ ]; }) [ "ntriples" ] // { scope = "routing graph"; }; };
  };
}
