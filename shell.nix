let
  # Pin specific version of nixpkgs to ensure reproducibility far into the future
  # Pinned: nixos-unstable 2025-05-04
  nixpkgs = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/979daf34c8cacebcd917d540070b52a3c2b9b16e.tar.gz";
    sha256 = "sha256-uKCfuDs7ZM3QpCE/jnfubTg459CnKnJG/LwqEVEdEiw=";
  };
in
  {pkgs ? import nixpkgs {}}: let
    mypkgs = import ./nix {inherit pkgs;};

    pyenv = pkgs.python3.withPackages (ps: [
      mypkgs.pyre-check
      ps.requests
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
