{
  lib,
  stdenv,
  fetchFromGitHub,
  autoreconfHook,
  ensureNewerSourcesForZipFilesHook,
  pkg-config,
  libxml2,
  libuuid,
  libpcap,
  pcre,
  protobuf,
  python3,
}:
stdenv.mkDerivation rec {
  pname = "emane";
  version = "1.3.3";

  src = fetchFromGitHub {
    owner = "adjacentlink";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-EmJZr609X3sbkNvwmxYvsczai/zGC4pNoASLTc2k8Hs=";
  };

  enableParallelBuilding = true;

  nativeBuildInputs = [
    autoreconfHook
    ensureNewerSourcesForZipFilesHook
    pkg-config
  ];

  buildInputs = [
    libxml2
    libuuid
    libpcap
    pcre
    protobuf
    python3.pkgs.setuptools
  ];

  preInstall = ''
    patchShebangs scripts/emanegenmanifests.sh
  '';
}
