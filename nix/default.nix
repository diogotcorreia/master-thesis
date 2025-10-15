{pkgs ? import <nixpkgs> {}}: {
  figtree = pkgs.callPackage ./figtree.nix {};
  pyre-check = pkgs.callPackage ./pyre-check.nix {};
}
