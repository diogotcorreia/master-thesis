{pkgs ? import <nixpkgs> {}}: {
  pyre-check = pkgs.callPackage ./pyre-check.nix {};
  sapp = pkgs.callPackage ./sapp.nix {};
}
