{
  outputs = _: {
    inherit (import ./.) lib;
    templates = import ./docs/templates.nix;
  };
}
