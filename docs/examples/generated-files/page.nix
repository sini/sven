{
  title = "Generated files";
  description = "flake.nix, README.md, CI files: written from fleet data by sini/files, and checked in CI.";
  section = "recipes";
  order = 7;

  body =
    { docs, r, ... }:
    [
      ''
        Some repo files are views of your fleet: the flake's inputs, a README with the host list, a CI matrix.
        Write them from the data, and a check fails when a committed file is stale.
        [sini/files](https://github.com/sini/files) does the writing. sven gives it the content.

        These docs are made this way: every page you read is a file that the docs fleet writes. So is sven's CI workflow:
        each stage is an aspect, and one job per system comes from the reference fleet's `ci.json`
        ([docs/modules/ci.nix](https://github.com/vic/sven/blob/main/docs/modules/ci.nix)).
      ''
      (docs.fileWith "{11,12-20}" "modules/fleet.nix")
      ''
        ## Inputs live with their users

        Each aspect declares the flake inputs it uses on the `inputs` sink. The host's input goes up to the fleet:
      ''
      (docs.fileWith "{14}" "modules/inputs.nix")
      (docs.file "modules/write.nix")
      ''
        The template's own `flake.nix` is that output. Remove the `web` aspect, and `nixpkgs` leaves the flake.
      ''
      (docs.file "flake.nix")
      (docs.sh ''
        nix run .#write-files   # write flake.nix and README.md
        nix flake check         # fails when a committed file is stale
      '')
      (docs.note "flake-file" ''
        [vic/flake-file](https://github.com/vic/flake-file) generates `flake.nix` from a module option, with follows and checks built in.
        The [reference fleet](https://github.com/vic/sven/blob/main/templates/fleet/modules/flake/flake-file.nix) uses it from a `flake-file` sink.
      '')
    ];

  checks =
    { r, dir, ... }:
    let
      gen = (builtins.head r.reduced.files."fleet:main").files.file;
    in
    {
      flake-is-generated = gen."flake.nix".text == builtins.readFile (dir + "/flake.nix");
      readme = gen."README.md".text == "# My fleet\n\nGenerated from the fleet. Hosts: `web`.\n";
      inputs =
        builtins.attrNames r.reduced.inputs."fleet:main" == [
          "files"
          "import-tree"
          "nixpkgs"
          "sven"
        ];
    };
}
