{ fetchFromGitHub, stdenvNoCC, ... }:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "figtree";
  version = "2.0.3";

  src = fetchFromGitHub {
    owner = "erikdkennedy";
    repo = "figtree";
    tag = "v${finalAttrs.version}";
    hash = "sha256-owzoM0zfKYxLJCQbL1eUE0cdSLVmm+QNRUGxbsNJ37I=";
  };

  installPhase = ''
    runHook preInstall

    install -m644 -Dt $out/share/fonts/opentype fonts/otf/*.otf

    runHook postInstall
  '';
})
