{
  fetchFromGitHub,
  fetchPypi,
  lib,
  python3,
  ...
}: let
  # using unstable because 0.9.23 depends on errpy which is not packaged
  version = "0-unstable-2025-02-19";
  sapp-src = fetchFromGitHub {
    owner = "facebook";
    repo = "sapp";
    rev = "4830cf48187e001b755fd2339e5c39e144b55613";
    hash = "sha256-+NDDGJhfUfa3+rOOKOQkMswGfBBlDgljAUdlPQIJwzs=";
  };

  flask-graphql = python3.pkgs.buildPythonPackage rec {
    pname = "flask-graphql";
    version = "2.0.1";
    src = fetchFromGitHub {
      owner = "graphql-python";
      repo = "flask-graphql";
      tag = "v${version}";
      hash = "sha256-bkcBEgMZ/KS3OZIPzszMA6khREq4FcueXSFV21sPRNk=";
    };
  };

  graphene-sqlalchemy = python3.pkgs.buildPythonPackage rec {
    pname = "flask-graphql";
    version = "3.0.0rc2";
    src = fetchFromGitHub {
      owner = "graphql-python";
      repo = "graphene-sqlalchemy";
      tag = "v${version}";
      hash = "sha256-Y7X7SlECfaM1hMJcihHVlOgmVSM7lNQfnw2Qwixt7Qg=";
    };
  };
in
  python3.pkgs.buildPythonPackage {
    inherit version;
    pname = "fb-sapp";
    pyproject = true;

    src = sapp-src;

    postPatch = ''
      substituteInPlace requirements.txt \
        --replace-fail 'graphene<3.0' 'graphene' \
        --replace-fail 'graphene-sqlalchemy>=2.3.0,<3' 'graphene-sqlalchemy'

      # fix import path
      substituteInPlace sapp/pipeline/__init__.py \
        --replace-fail 'tools.sapp.sapp.' 'sapp.'
    '';

    build-system = with python3.pkgs; [
      setuptools
    ];

    dependencies = with python3.pkgs; [
      click
      click-log
      flask
      flask-cors
      flask-graphql
      graphene
      graphene-sqlalchemy
      (ipython.overridePythonAttrs (prev: {
        version = "8.3.0";
        src = fetchPypi {
          pname = prev.pname;
          version = "8.3.0";
          hash = "sha256-gHrjz0O4RpPJJy9wNoRAqafqoufmiC2tlDwy+/flFAI=";
        };
        dependencies = prev.dependencies ++ [backcall pickleshare];

        # tests are broken due to mismatching pytest version
        # https://github.com/ipython/ipython/issues/14390
        doCheck = false;
      }))
      munch
      prompt-toolkit
      psutil
      pygments
      pyre-extensions
      sqlalchemy
      traitlets
      typing-extensions
      xxhash
      zstandard
      werkzeug

      promise
    ];

    meta = {
      homepage = "https://github.com/facebook/sapp";
      description = "Static Analysis Post-Processor for processing taint analysis results";
      license = lib.licenses.mit;
    };
  }
