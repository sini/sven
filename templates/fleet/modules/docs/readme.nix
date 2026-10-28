# README.md: the guide (`_guide.md`) plus live tables and diagrams computed from the fleet's own queries.
# Every diagram is data: `sven.lib.graph` (scopes, routed elements), kind declarations, and sink values.
{ sven, lib, ... }:
let
  g = sven.lib.graph;
  code = xs: lib.concatMapStringsSep ", " (x: "`${x}`") xs;
  names = v: if lib.isAttrs v then lib.attrNames v else [ ];
  sorted = xs: lib.sort (a: b: a < b) (lib.unique xs);
  kindRow = k: let d = sven.kinds.${k}; in
    "| `${k}` | ${code (names (d.fields or { }))} | ${code (names (d.spawns or { }))} | ${code (names (d.sinks or { }))} | ${toString (lib.length (lib.filter (s: s.kind == k) g.scopes))} |";
  kinds = ''
    ## This fleet, live
    Generated from the fleet's queries: ${toString (lib.length g.scopes)} scopes, ${toString (lib.length (lib.attrNames sven.kinds))} kinds, ${toString (lib.length (lib.attrNames sven.aspects))} aspects, ${toString (lib.length g.edges)} routed elements.
    | Kind | Fields | Spawns | Sinks | Scopes |
    |---|---|---|---|---|
    ${lib.concatMapStringsSep "\n" kindRow (lib.attrNames sven.kinds)}
    A kind with 0 scopes is data: nothing spawns it.
  '';

  # ── one thin mermaid emitter for every view: nodes { id; label; kind; group }, edges { from; to; label; live } ──
  node = id: "n${builtins.substring 0 10 (builtins.hashString "md5" id)}";
  q = l: ''"${lib.replaceStrings [ "\"" ] [ "'" ] l}"'';
  shape = {
    mac = l: "(${q l})"; guest = l: "[[${q l}]]"; home = l: "[/${q l}/]"; user = l: "((${q l}))";
    member = l: "{{${q l}}}"; instance = l: "{{${q l}}}"; sink = l: "(${q l})"; output = l: "[(${q l})]";
  };
  box = n: node n.id + (shape.${n.kind} or (l: "[${q l}]")) n.label;
  mermaid = view:
    let
      inside = p: lib.filter (n: (n.group or null) == p.id) view.nodes;
      isGroup = n: lib.any (m: (m.group or null) == n.id) view.nodes;
      draw = n: if isGroup n then [ "  subgraph ${node n.id} [${q n.label}]" ] ++ map (m: "    ${box m}") (inside n) ++ [ "  end" ] else [ "  ${box n}" ];
      edge = e: "  ${node e.from} ${if e.live or true then "-->" else "-.->"}${if (e.label or "") == "" then "" else "|${q e.label}|"} ${node e.to}";
    in lib.concatStringsSep "\n" ([ "```mermaid" "flowchart LR" ] ++ lib.concatMap draw (lib.filter (n: (n.group or null) == null) view.nodes) ++ map edge view.edges ++ [ "```" ]);
  short = xs: let s = sorted xs; in lib.concatStringsSep ", " (lib.take 6 s) + lib.optionalString (lib.length s > 6) ", +${toString (lib.length s - 6)}";
  kindOf = lib.listToAttrs (map (s: lib.nameValuePair s.id s.kind) g.scopes);
  nameOf = lib.listToAttrs (map (s: lib.nameValuePair s.id s.name) g.scopes);
  parentOf = id: lib.concatStringsSep "/" (lib.init (lib.splitString "/" id));

  # fleet map: machines grouped by environment; every scope under its parent
  envOf = s: lib.findFirst (e: lib.hasPrefix "${e.id}/" s.id) null (lib.filter (e: e.kind == "environment") g.scopes);
  fleetMap = {
    nodes = map (s: { inherit (s) id kind; label = if s.kind == "environment" then "environment ${s.name}" else s.name;
      group = if s.kind != "environment" && envOf s != null && kindOf.${parentOf s.id} or null == "environment" then (envOf s).id else null; }) g.scopes;
    edges = map (s: { from = parentOf s.id; to = s.id; }) (lib.filter (s: lib.hasInfix "/" s.id && kindOf.${parentOf s.id} or null != "environment") g.scopes);
  };

  # sink forwarding: a sink's key that names another sink feeds it (dashed); `out` reaches flake outputs with live receivers
  meta = [ "reduce" "of" "at" "out" ];
  sinkDecls = lib.concatLists (lib.mapAttrsToList (k: d: lib.mapAttrsToList (n: v: { kind = k; name = n; decl = if lib.isAttrs v then v else { }; }) (d.sinks or { })) sven.kinds);
  receiversOf = sink: sorted (map (e: nameOf.${e.to}) (lib.filter (e: e.sink == sink) g.edges));
  forwards = {
    nodes = map (n: { id = "sink:${n}"; label = n; kind = "sink"; }) (sorted (map (d: d.name) sinkDecls ++ lib.concatMap (d: lib.subtractLists meta (names d.decl)) sinkDecls))
      ++ [ { id = "flake"; label = "flake outputs"; kind = "output"; } ];
    edges = lib.unique (lib.concatMap (d: map (t: { from = "sink:${d.name}"; to = "sink:${t}"; label = d.kind; live = false; }) (lib.subtractLists meta (names d.decl))
      ++ lib.optional (d.decl ? out) { from = "sink:${d.name}"; to = "flake"; label = short (receiversOf d.name); }) sinkDecls);
  };

  # pools: an element routed from one kind up to another, one edge per (sink, from kind, to kind)
  routed = lib.filter (e: kindOf.${e.from} != kindOf.${e.to}) g.edges;
  pools = {
    nodes = map (k: { id = "kind:${k}"; label = k; kind = k; }) (sorted (map (e: kindOf.${e.from}) routed ++ map (e: kindOf.${e.to}) routed));
    edges = map (x: { from = "kind:${x.f}"; to = "kind:${x.t}"; label = lib.concatStringsSep ", " (sorted x.ss); })
      (lib.mapAttrsToList (_: es: { inherit (lib.head es) f t; ss = map (e: e.s) es; })
        (lib.groupBy (x: "${x.f}>${x.t}") (map (e: { f = kindOf.${e.from}; t = kindOf.${e.to}; s = e.sink; }) routed)));
  };

  # clan instances: instance (service) to the machines of each role
  members = lib.filter (s: s.kind == "member") g.scopes;
  instanceOf = s: lib.head (lib.splitString "." s.name);
  clan = {
    nodes = map (i: { id = "inst:${i}"; label = "${i} (${sven.helpers.clan.instances.${i}.module})"; kind = "instance"; }) (sorted (map instanceOf members))
      ++ map (m: { id = m; label = nameOf.${m}; kind = kindOf.${m}; }) (sorted (map (s: parentOf s.id) members));
    edges = map (s: { from = "inst:${instanceOf s}"; to = parentOf s.id; label = lib.last (lib.splitString "." s.name); }) members;
  };

  # vars: generator dependencies; a shared generator is one node for all its machines
  vars = generators: {
    nodes = lib.mapAttrsToList (k: v: { id = "gen:${k}"; label = "${k} · ${short v.machines}"; kind = if v.share or false then "member" else "gen"; }) generators;
    edges = lib.concatLists (lib.mapAttrsToList (k: v: lib.concatMap (d:
      let m = lib.head v.machines; t = if generators ? ${d} then d else "${d}@${m}"; in lib.optional (generators ? ${t}) { from = "gen:${t}"; to = "gen:${k}"; }) (v.dependencies or [ ])) generators);
  };

  # deploy order: a host deploys after what it depends on
  hosts = lib.filterAttrs (_: h: h ? addr) sven.host;
  deploy = {
    nodes = lib.mapAttrsToList (n: _: { id = "host:${n}"; label = n; kind = "host"; }) (lib.filterAttrs (n: h: h.dependsOn != [ ] || lib.any (o: lib.any (d: d.name == n) o.dependsOn) (lib.attrValues hosts)) hosts);
    edges = lib.concatLists (lib.mapAttrsToList (n: h: map (d: { from = "host:${d.name}"; to = "host:${n}"; label = "before"; }) h.dependsOn) hosts);
  };

  diagrams = generators: ''
    ### Fleet map
    Every scope, under its parent. Machines sit in their environment. `[host]` `(mac)` `[[guest]]` `[/home/]` `((user))` `{{member}}`.

    ${mermaid fleetMap}

    <details><summary>Sinks, pools, clan instances, vars, deploy order (diagrams)</summary>

    **Sink forwarding**: a dashed edge is a sink key that feeds another sink (label: the kind). A solid edge is `out`, labelled with the receivers that build an output.

    ${mermaid forwards}

    **Pools**: elements routed up from one kind to another, labelled with the sinks.

    ${mermaid pools}

    **clan instances**: each instance (its service) to the machines of each role.

    ${mermaid clan}

    **vars generators**: an edge is a dependency. A hexagon is shared by every machine that uses it.

    ${mermaid (vars generators)}

    **Deploy order** (`dependsOn`).

    ${mermaid deploy}

    </details>
  '';
  jobs = ci: ''
    ### CI jobs (`ci.json`)
    | Job | System | Builds |
    |---|---|---|
    ${lib.concatMapStringsSep "\n" (j: "| `${j.name}` | `${j.system}` | `${j.attr}` |") (lib.attrValues ci)}
  '';
in
{
  sven.aspects.readme = {
    at = sven.system.x86_64-linux;
    files = { ci, generators, ... }: {
      files.file."README.md".text = lib.concatStringsSep "\n" [
        "# sven fleet"
        ""
        "<!-- Generated by github:sini/files from modules/docs. Edit there, then run `nix run .#write-files`. -->"
        ""
        (builtins.readFile ./_guide.md)
        kinds
        (diagrams generators)
        (jobs ci)
      ];
    };
  };
}
