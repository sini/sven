# vix: a child kind declared in another file. Each system gets editor profiles; `features` gate aspects;
# the `vim` sink builds one package per profile.
{ sven, lib, inputs, ... }:
let
  inherit (sven.helpers) listOf enum;
  features = [ "lsp" "git" "theme" ];
  has = f: sven.lib.all [ sven.kinds.vim (s: lib.elem f s.features) ]; # a predicate runs at every scope: test the kind first
in
{
  sven.kinds.system.spawns.vim = s: lib.optionalAttrs (s.name == "x86_64-linux") sven.vim;
  sven.kinds.vim = {
    fields = { features = sven.lib.opt (listOf (enum features)) [ ]; theme = sven.lib.maybe lib.types.str; };
    sinks.vim = {
      reduce = sven.lib.reduce.set;
      out = { system, vim, scope, ... }: {
        packages.${system.name}."vim-${scope.name}" = inputs.nixpkgs.legacyPackages.${system.name}.writeText "vim-${scope.name}.lua" (lib.concatLines vim);
      };
    };
  };
  sven.vim.dev = { features = [ "lsp" "git" ]; theme = "tokyonight"; };
  sven.vim.min = { };
  sven.aspects.vim-lsp = { at = has "lsp"; vim = "vim.lsp.enable('nixd')"; };
  sven.aspects.vim-git = { at = has "git"; vim = "require('gitsigns').setup()"; };
  sven.aspects.vim-theme = { at = sven.lib.all [ sven.kinds.vim (s: s.theme != null) ]; vim = { vim, ... }: "vim.cmd.colorscheme('${vim.theme}')"; };
  sven.aspects.vim-base = { at = sven.kinds.vim; vim = "vim.o.number = true"; };
}
