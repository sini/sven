# A root emission: the overlay goes to the fleet's `overlays` pool; every machine reads it. A wrapped `final: prev:`.
{ sven, inputs, ... }:
{
  sven.aspects.unstable-overlay = {
    at = sven.fleet.main;
    overlays =
      { ... }:
      final: prev: {
        inherit (inputs.nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system}) helix;
      };
  };
}
