# Shared values. `sven.helpers` is a query like any other declaration.
{
  sven,
  lib,
  inputs,
  ...
}:
let
  inherit (sven.lib) same holds;
in
{
  sven.helpers = {
    machines = [
      sven.kinds.host
      sven.kinds.guest
      sven.kinds.mac
    ];
    linux = [
      sven.kinds.host
      sven.kinds.guest
    ];
    listOf = t: sven.lib.is (v: lib.isList v && lib.all t.check v);
    enum = xs: sven.lib.is (v: lib.elem v xs);
    pkgsOf = m: m.channel.nixpkgs.legacyPackages.${m.system.name};
    inEnv = xs: s: lib.filterAttrs (_: x: same x.environment s) xs;
    upTo = p: s: lib.findFirst (holds p) null (lib.reverseList s.up); # nearest ancestor-or-self where p holds
    # nested groups: every group that contains one of gs, transitively
    closure =
      gs:
      map (x: x.g) (
        builtins.genericClosure {
          startSet = map (g: {
            key = g.name;
            inherit g;
          }) gs;
          operator =
            x:
            map (p: {
              key = p.name;
              g = p;
            }) (lib.filter (p: lib.any (same x.g) p.members) (lib.attrValues sven.group));
        }
      );
    # ACL: a posix group of the user meets the environment's or the machine's grants, and the machine's gates when it has any
    meets = xs: ys: lib.any (x: lib.any (same x) ys) xs;
    posixOf = u: lib.filter (g: g.label == "posix") (sven.helpers.closure u.groups);
    usersOn =
      s:
      lib.filterAttrs (
        _: u:
        let
          gs = sven.helpers.posixOf u;
        in
        sven.helpers.meets gs (s.environment.grants ++ s.grants)
        && (s.gates == [ ] || sven.helpers.meets gs s.gates)
      ) sven.user;
    flatten = a: ms: lib.mkMerge (map (m: if lib.isFunction m then m a else m) ms); # config-only submodules (users.users.<n>)
    noGui =
      system: h: cfg: bad:
      let
        hit = lib.intersectLists bad (map lib.getName cfg.config.environment.systemPackages);
      in
      inputs.nixpkgs.legacyPackages.${system.name}.runCommand "${h}-no-gui" { } (
        if hit == [ ] then "touch $out" else "echo 'gui on ${h}: ${toString hit}'; exit 1"
      );
    mermaid =
      g:
      let
        n = id: "s${builtins.hashString "md5" id}[\"${id}\"]";
      in
      lib.concatLines (
        [ "flowchart TD" ]
        ++ map (s: "  ${n s.id}") g.scopes
        ++ map (e: "  ${n e.from} -->|${e.sink}| ${n e.to}") (lib.filter (e: e.from != e.to) g.edges)
      );
    ids = lib.listToAttrs (
      lib.imap0 (i: n: lib.nameValuePair n i) (
        lib.sort (a: b: a < b) (map (s: s.name) (lib.filter (s: s.kind == "host") sven.lib.graph.scopes))
      )
    ); # deterministic: sorted host scope names
  };
}
