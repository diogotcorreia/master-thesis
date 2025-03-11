{
  fetchFromGitHub,
  lib,
  ocamlPackages,
  python3,
  rsync,
  writeText,
  ...
}: let
  # using unstable because 0.9.23 depends on errpy which is not packaged
  version = "0-unstable-2025-02-28";
  version' = "0.9.23";
  pyre-src = fetchFromGitHub {
    owner = "facebook";
    repo = "pyre-check";
    rev = "4d61987b64856718fa2800c97131b5e164667790";
    hash = "sha256-jc/hXclEdDUMq5x7dmAcld9Ge52faudm5yvk3pa7JpI=";
  };
  versionFile = writeText "version.ml" ''
    let build_info () =
      "pyre-nixpkgs ${version}"
    let version () =
      "${version}"
    let log_version_banner () =
        Log.info "Running as pid: %d" (Unix.getpid ());
        Log.info "Version: %s" (version ());
        Log.info "Build info: %s" (build_info ())
  '';
  ppx_make = ocamlPackages.buildDunePackage {
    pname = "ppx_make";
    version = "0.3.4";

    src = fetchFromGitHub {
      owner = "bn-d";
      repo = "ppx_make";
      tag = "v0.3.4";
      hash = "sha256-jR+2l5JcB3wT0YsnQCTwptarp4cZwi8GFweQEwSn4oo=";
    };

    buildInputs = with ocamlPackages; [
      ppxlib
    ];
  };
  pyre-ast = ocamlPackages.buildDunePackage {
    pname = "pyre-ast";
    version = "0.1.11";

    src = fetchFromGitHub {
      owner = "grievejia";
      repo = "pyre-ast";
      tag = "0.1.11";
      hash = "sha256-+LeTCDt+t/dmqIWcMvPB9A3KLyAAboUSVjiAfL1BTyE=";
    };

    buildInputs = with ocamlPackages; [
      ppx_sexp_conv
      ppx_compare
      ppx_hash
      ppx_deriving
      ppx_make
    ];
  };
  hack_parallel = ocamlPackages.buildDunePackage {
    inherit version;
    pname = "hack_parallel";

    src = pyre-src;
    sourceRoot = "${pyre-src.name}/source";

    env.DUNE_PROFILE = "release";

    buildInputs = with ocamlPackages; [
      core
    ];

    postPatch = ''
      # no idea why these have empty versions, but dune refuses to build like this
      substituteInPlace ./hack_parallel.opam --replace-fail 'version: ""' 'version: "${version}"'
      substituteInPlace ./pyrelib.opam --replace-fail 'version: ""' 'version: "${version}"'
    '';

    postConfigure = ''
      substitute ./dune.in ./dune \
        --replace-fail "%VERSION%" "external" \
        --replace-fail "%CUSTOM_LINKER_OPTION%" ""

      cat > ./hack_parallel/hack_parallel/utils/get_build_id.c <<EOF
      const char* const BuildInfo_kRevision = "${version}";
      const unsigned long BuildInfo_kRevisionCommitTimeUnix = 0ul;
      EOF
    '';
  };

  pyre-bin = ocamlPackages.buildDunePackage {
    inherit version;
    pname = "pyrelib";

    src = pyre-src;
    sourceRoot = "${pyre-src.name}/source";

    duneVersion = "3";

    env.DUNE_PROFILE = "release";

    nativeBuildInputs = with ocamlPackages; [
      menhir
    ];
    buildInputs = with ocamlPackages; [
      base64
      cmdliner
      core
      re2
      yojson
      jsonm
      ppx_deriving_yojson
      ppx_yojson_conv
      ounit2
      lwt
      lwt_ppx
      mtime

      pyre-ast
      hack_parallel
    ];

    postPatch = ''
      # no idea why these have empty versions, but dune refuses to build like this
      substituteInPlace ./hack_parallel.opam --replace-fail 'version: ""' 'version: "${version}"'
      substituteInPlace ./pyrelib.opam --replace-fail 'version: ""' 'version: "${version}"'
    '';

    postConfigure = ''
      cp ${versionFile} ./version.ml
      substitute ./dune.in ./dune \
        --replace-fail "%VERSION%" "external" \
        --replace-fail "%CUSTOM_LINKER_OPTION%" ""
    '';
  };
in
  python3.pkgs.buildPythonPackage {
    inherit version;
    pname = "pyre-check";
    pyproject = true;

    src = pyre-src;

    nativeBuildInputs = [
      rsync
    ];

    build-system = with python3.pkgs; [
      setuptools
      twine
    ];

    dependencies = with python3.pkgs; [
      click
      dataclasses-json
      libcst
      psutil
      pyre-extensions
      tabulate
      typing-extensions
      typing-inspect
      tomli
      tomli-w
    ];

    postPatch = ''
      substituteInPlace scripts/pypi/build_pypi_package.py \
        --replace-fail 'pyre_directory / "source" / "_build/default/main.exe"' 'Path("${pyre-bin}/bin/main.exe")' \
        --replace-fail '/lib64/ld-linux-x86-64.so.2' ""

      substituteInPlace requirements.txt \
        --replace-fail 'testslide>=2.7.0' "" \
        --replace-fail 'dataclasses-json==0.5.7' 'dataclasses-json>=0.5.7'
    '';

    buildPhase = ''
      mkdir dist
      PYTHONPATH="$PYTHONPATH:./scripts" python3 scripts/pypi \
        --version "${version'}" \
        --typeshed-path ./stubs/typeshed/typeshed \
        --output-dir "./dist"
    '';

    passthru = {
      pyre = pyre-bin;
    };

    meta = {
      changelog = "https://github.com/facebook/toolz/releases/tag/${version}";
      homepage = "https://github.com/facebook/pyre-check";
      description = "Performant type-checking for python";
      license = lib.licenses.mit;
    };
  }
