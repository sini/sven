{
  outputs = _: {
    inherit (import ./.) lib;
    inherit (import ./docs) templates;
  };
}
