# rdf.nix: an eval result as sorted, de-duplicated N-Triples, and its content hash. Builtins only.
let
  b = builtins;
  base = "https://sven.dev/fleet/";
  bad = [ "%" " " "\"" "<" ">" "{" "}" "|" "\\" "^" "`" "\n" "\r" "\t" ];
  iriPart = b.replaceStrings bad [ "%25" "%20" "%22" "%3C" "%3E" "%7B" "%7D" "%7C" "%5C" "%5E" "%60" "%0A" "%0D" "%09" ];
  iri = ns: x: "<${base}${ns}/${iriPart x}>";
  pred = n: "<${base}sven/${n}>";
  type = "<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>";
  lit = s: "\"${b.replaceStrings [ "\\" "\"" "\n" "\r" "\t" ] [ "\\\\" "\\\"" "\\n" "\\r" "\\t" ] s}\"";
  h16 = s: b.substring 0 16 (b.hashString "sha256" s);
  triple = s: p: o: "${s} ${p} ${o} .";
  parentOf = id: let m = b.match "(.*)/[^/]*" id; in if m == null then [ ] else b.head m;

  triples = r:
    let
      scope = s: let n = iri "scope" s.id; in
        [ (triple n type (iri "kind" s.kind)) (triple n (pred "name") (lit s.name)) ]
        ++ (let p = parentOf s.id; in if p == [ ] then [ ] else [ (triple n (pred "parent") (iri "scope" p)) ]);
      on = a: b.filter (id: r.active.${a}.${id}) (b.attrNames r.active.${a});
      aspect = a: map (id: triple (iri "scope" id) (pred "has") (iri "aspect" a)) (on a);
      edge = e:
        let n = iri "edge" (h16 "${e.sink}|${e.from}|${e.to}|${e.origin}"); in [
          (triple n (pred "sink") (lit e.sink))
          (triple n (pred "from") (iri "scope" e.from))
          (triple n (pred "to") (iri "scope" e.to))
          (triple n (pred "origin") (lit e.origin))
        ];
      error = e: let n = iri "error" (h16 "${e.from}|${e.error}"); in [ (triple n (pred "message") (lit e.error)) (triple n (pred "at") (lit e.from)) ];
      all = b.concatMap scope r.graph.scopes ++ b.concatMap aspect (b.attrNames r.active)
        ++ b.concatMap edge r.graph.edges ++ b.concatMap error r.errors;
      uniq = map (i: i.key) (b.genericClosure { startSet = map (key: { inherit key; }) all; operator = _: [ ]; });
    in
    b.sort b.lessThan uniq;

  ntriples = r: b.concatStringsSep "\n" (triples r) + "\n";
in
{
  inherit triples ntriples;
  share = r: let nt = ntriples r; in { ntriples = nt; sha256 = b.hashString "sha256" nt; count = b.length (triples r); };
}
