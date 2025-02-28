{pkgs ? import <nixpkgs> {}}:
pkgs.mkShell {
  buildInputs = with pkgs; [
    typst
    typstyle

    (pkgs.callPackage ./nix/pyre-check.nix {})
  ];
}
