# Per-system outputs, a VM check, and a check on a realized config (#60).
{ sven, inputs, ... }:
{
  sven.aspects.tools = {
    at = sven.kinds.system;
    packages =
      { system, ... }:
      {
        inherit (inputs.nixpkgs.legacyPackages.${system.name}) hello;
      };
  };
  sven.aspects.web-check = {
    at = sven.system.x86_64-linux;
    checks.web = {
      nodes.web = {
        services.nginx.enable = true;
        networking.firewall.allowedTCPPorts = [ 80 ];
      };
      nodes.client = { };
      testScript = ''
        start_all()
        web.wait_for_unit("nginx")
        client.wait_until_succeeds("curl -sf http://web/")
      '';
    };
  };
  sven.aspects.headless = {
    at = sven.system.x86_64-linux;
    no-gui.lb = [ "firefox" ];
  };
  sven.aspects.docs = {
    at = sven.kinds.fleet;
    out =
      { ... }:
      {
        docs.mermaid = sven.helpers.mermaid sven.lib.graph;
      };
  };
}
