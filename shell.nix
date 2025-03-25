let
  # Pin specific version of nixpkgs to ensure reproducibility far into the future
  # Pinned: nixos-24.11 2025-03-21
  nixpkgs = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/7105ae3957700a9646cc4b766f5815b23ed0c682.tar.gz";
    sha256 = "sha256-8XfURTDxOm6+33swQJu/hx6xw1Tznl8vJJN5HwVqckg=";
  };
in
  {pkgs ? import nixpkgs {}}: let
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
