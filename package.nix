{
  lib,
  symlinkJoin,
  stdenv,
  nix-filter,
  isPy3k,
  buildPythonPackage,
  pythonRelaxDepsHook,
  autoreconfHook,
  pkg-config,
  nftables,
  procps,
  iproute2,
  ethtool,
  mount,
  umount,
  libev,
  openvswitch,
  imagemagick,
  # Python Dependencies
  invoke,
  lxml,
  Mako,
  Fabric,
  poetry,
  pyproj,
  protobuf,
  pillow,
  pyyaml,
  netaddr,
  grpcio,
  grpcio-tools,
  tkinter,
  # Docs
  withDocs ? true,
  help2man,
  sphinx,
  sphinx-rtd-theme,
  # Testing
  nixosTests,
  pytest,
  mock,
}:
buildPythonPackage rec {
  pname = "core";
  version = "8.2.0";
  format = "pyproject";
  disabled = !isPy3k;

  src = nix-filter {
    root = ./.;
    include = [
      "daemon"
      "docs"
      "gui"
      "man"
      "netns"
      "CHANGELOG.md"
      "configure.ac"
      "LICENCE"
      "Makefile.am"
      "README.md"
    ];
  };

  preAutoreconf = ''
    # Create files for AutoReconf
    touch NEWS README AUTHORS ChangeLog

    # Patch out path limitation
    substituteInPlace configure.ac --replace ", \$SEARCHPATH" ""
  '';

  configureFlags =
    []
    ++ lib.optionals withDocs [
      "--enable-docs"
    ];

  # Tools are not added to the path if this is true and so configure can't find them
  strictDeps = false;

  nativeBuildInputs =
    [
      autoreconfHook
      pkg-config
      pythonRelaxDepsHook
    ]
    ++ lib.optionals withDocs [
      help2man
      sphinx
      sphinx-rtd-theme
    ];

  buildInputs = [
    nftables
    procps
    iproute2
    ethtool
    mount
    umount
    libev
    openvswitch
    imagemagick
  ];

  pythonRelaxDeps = ["fabric" "grpcio" "invoke" "lxml" "mako" "netaddr" "pillow" "protobuf" "pyproj" "pyyaml"];
  propagatedBuildInputs = [
    invoke
    lxml
    Mako
    Fabric
    poetry
    pyproj
    protobuf
    pillow
    pyyaml
    netaddr
    grpcio
    grpcio-tools
    tkinter
  ];

  buildPhase = ''
    make

    pushd daemon
    runHook pipBuildPhase
    mv dist ../
    popd
  '';

  installPhase = ''
    make install
    runHook pipInstallPhase
    install -Dm755 daemon/scripts/* -t $out/bin

    mkdir -p $out/etc/core
    cp daemon/data/*.conf $out/etc/core/
  '';

  checkInputs = [pytest mock];
  checkPhase = ''
    pushd daemon
    pytest -v --mock --lf -x tests
    popd
  '';

  meta = with lib; {
    homepage = "https://coreemu.github.io/core/";
    description = "CORE (Common Open Research Emulator) is a tool for building virtual networks.";
    longDescription = ''
      CORE (Common Open Research Emulator) is a tool for building virtual networks. As an emulator, CORE builds a representation of a real computer network that runs in real time, as opposed to simulation, where abstract models are used. The live-running emulation can be connected to physical networks and routers. It provides an environment for running real applications and protocols, taking advantage of tools provided by the Linux operating system.
    '';
    license = licenses.bsd2;
    maintainers = with maintainers; [];
    platforms = platforms.linux;
    badPlatforms = platforms.i686;
  };
}
