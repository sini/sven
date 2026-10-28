# The docs site as a sven fleet. The root `site` spawns one scope per page. Sections are data.
# Each page gives repo files (the .mdx), a sidebar entry, its template and its tests; the site reduces them to flake outputs.
{ sven, lib, inputs, ... }:
let
  inherit (sven.lib) is;
  inherit (sven.lib.reduce) merge list;
  str = lib.types.str;
  int = lib.types.int;
in
{
  sven.kinds.section.fields = { title = str; order = int; };
  sven.kinds.page.fields = {
    title = str;
    description = str;
    section = sven.kinds.section;
    order = int;
    dir = is builtins.isPath; # the example directory: a flake template
    badge = sven.lib.maybe str; # a sidebar badge: "new", "advanced"
    route = sven.lib.derive str (self: "${self.section.name}/${self.name}"); # the route
  };
  sven.kinds.site = {
    spawns.page = _: sven.page;
    sinks = {
      out.reduce = merge;
      sidebar = { reduce = list; of = is (v: v ? section && v ? item); };
      templates = { reduce = merge; out = { templates, ... }: { inherit templates; }; };
      # `nix flake check` runs the oracles too: one check for the fast ones, one for the NixOS evaluations
      tests = {
        reduce = merge;
        out = { tests, ... }:
          let
            failed = k: lib.concatLists (lib.mapAttrsToList (p: t: map (c: "${p}/${c}") (lib.attrNames (lib.filterAttrs (_: ok: !ok) t.${k}))) tests);
            check = k: inputs.nixpkgs.legacyPackages.x86_64-linux.runCommand "docs-${k}" { }
              (if failed k == [ ] then "touch $out" else "echo 'failed: ${toString (failed k)}'; exit 1");
          in { inherit tests; checks.x86_64-linux = { examples = check "fast"; examples-e2e = check "e2e"; }; };
      };
    };
  };
  sven.site.docs = { };
  sven.flake = { out, ... }: out;

  sven.section = {
    start = { title = "Start"; order = 1; };
    migrate = { title = "Move to sven"; order = 2; };
    concepts = { title = "Concepts"; order = 3; };
    recipes = { title = "Recipes"; order = 4; };
    query = { title = "Ask and prove"; order = 5; };
    agents = { title = "For agents"; order = 6; };
    perf = { title = "Performance"; order = 7; };
    reference = { title = "Reference"; order = 8; };
    project = { title = "Project"; order = 9; };
  };
}
