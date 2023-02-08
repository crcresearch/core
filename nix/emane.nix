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
  python,
  # Docs
  withDocs ? true,
  doxygen,
  graphviz,
}:
python.pkgs.buildPythonApplication rec {
  pname = "emane";
  version = "1.3.3";
  format = "setuptools";

  outputs = ["out"] ++ lib.optionals withDocs ["doc"];

  src = fetchFromGitHub {
    owner = "adjacentlink";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-EmJZr609X3sbkNvwmxYvsczai/zGC4pNoASLTc2k8Hs=";
  };

  # Compile time dependencies
  nativeBuildInputs =
    [
      pkg-config
      autoreconfHook
      ensureNewerSourcesForZipFilesHook
      protobuf
    ]
    ++ lib.optionals withDocs [
      doxygen
      graphviz
    ];

  # Runtime dependencies
  buildInputs = [
    libxml2
    libuuid
    libpcap
    pcre
    protobuf
  ];

  # Propagated runtime dependencies
  propagatedBuildInputs = with python.pkgs; [
    protobuf
    libxml2
  ];

  # Configure
  preAutoreconf = ''
    substituteInPlace src/python/Makefile.am --replace "setup.py build" "setup.py bdist_wheel"

    # Remove python install step
    sed -i -e '/^install-exec-hook:/,/^uninstall-hook/{/^install-exec-hook:/d; /^uninstall-hook:/p; d}' src/python/Makefile.am
  '';

  # Build
  buildPhase =
    ''
      mkdir -p dist
      make -j $NIX_BUILD_CORES
      mv src/python/dist/*.whl dist/
    ''
    + lib.optionalString withDocs ''
      make -C doc doxygen
    '';

  # Install
  installPhase = ''
    patchShebangs scripts/emanegenmanifests.sh

    make install
    runHook pipInstallPhase
  '';

  postInstall = lib.optionalString withDocs ''
    mkdir -p $out/share/doc/$pname
    mv doc/html $out/share/doc/$pname/html
  '';

  # Fixup - Needed so emane can find plugins
  postFixup = ''
    for i in $out/lib/libemane.so $out/lib/libeelgenerator.so
    do
      patchelf --set-rpath "$out/lib:$(patchelf --print-rpath $i)" $i
    done
  '';

  # Checks
  dontUseSetuptoolsCheck = true;
  pythonImportsCheck = ["emane"];
}
