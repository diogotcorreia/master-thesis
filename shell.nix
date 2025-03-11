{pkgs ? import <nixpkgs> {}}: let
  mypkgs = import ./nix {inherit pkgs;};
in
  pkgs.mkShell {
    buildInputs = with pkgs; [
      typst
      typstyle

      (python3.withPackages (ps: [
        mypkgs.pyre-check
      ]))
    ];
  }
