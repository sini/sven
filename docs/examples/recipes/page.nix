{
  title = "All recipes";
  description = "Complete fleets for common jobs, from the simplest to the most advanced. Each one is a template.";
  section = "recipes";
  order = 0;
  route = "recipes";

  body = { docs, pages, ... }: [
    ''
      Each recipe is a complete, tested flake template. Read the page, then copy the template and change it.
      They go from simple to advanced: start at the top.
    ''
    (docs.links (map (p: { title = p.title; href = "/${p.route}/"; inherit (p) description; })
      (builtins.filter (p: p.section == "recipes" && p.route != "recipes") pages)))
  ];
}
