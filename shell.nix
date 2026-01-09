let
  # Pin specific version of nixpkgs to ensure reproducibility far into the future
  # Pinned: nixos-unstable 2025-05-04
  nixpkgs = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/979daf34c8cacebcd917d540070b52a3c2b9b16e.tar.gz";
    sha256 = "sha256-uKCfuDs7ZM3QpCE/jnfubTg459CnKnJG/LwqEVEdEiw=";
  };
in
  {pkgs ? import nixpkgs {}}: let
    inherit (pkgs) lib;
    mypkgs = import ./nix {inherit pkgs;};

    pyenv = pkgs.python3.withPackages (ps: [
      mypkgs.pyre-check
      ps.requests
      ps.tomli-w
    ]);

    typstFonts = [
      mypkgs.figtree
      pkgs.liberation_ttf
    ];
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

        # common dependencies for building python wheels
        pkg-config
        libpq.pg_config # pg_config for psycopg
        mariadb
        openldap # for python-ldap
        cyrus_sasl # for python-ldap
        libxslt # for xmlsec
        libxml2 # for xmlsec
        xmlsec # for xmlsec
        libtool # for xmlsec
        zlib # for lxml
      ];

      shellHook = ''
        export UV_NO_MANAGED_PYTHON=1
        export UV_PYTHON="${pkgs.python310}/bin/python"
        export TYPST_FONT_PATHS="${lib.concatStringsSep ":" typstFonts}"
      '';
    }
