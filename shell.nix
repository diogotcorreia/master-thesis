let
  # Pin specific version of nixpkgs to ensure reproducibility far into the future
  # Pinned: nixos-unstable 2025-03-25
  nixpkgs = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/698214a32beb4f4c8e3942372c694f40848b360d.tar.gz";
    sha256 = "sha256-hw63HnwnqU3ZQfsMclLhMvOezpM7RSB0dMAtD5/sOiw=";
  };
in
  {pkgs ? import nixpkgs {}}: let
    mypkgs = import ./nix {inherit pkgs;};

    pyenv = pkgs.python3.withPackages (ps: [
      mypkgs.pyre-check
    ]);
  in
    pkgs.mkShell {
      buildInputs = with pkgs; [
        # for thesis writing
        typst
        typstyle

        # for tool
        cargo
        rustc
        rustfmt
        rust-analyzer
        clippy

        # for tool runtime
        pyenv
        uv
      ];

      shellHook = ''
        export UV_NO_MANAGED_PYTHON=1
        export UV_PYTHON="${pyenv}/bin/python"
      '';
    }
