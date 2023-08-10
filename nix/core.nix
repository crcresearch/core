{
  lib,
  symlinkJoin,
  stdenv,
  gitignore,
  isPy3k,
  buildPythonPackage,
  pythonRelaxDepsHook,
  autoreconfHook,
  makeWrapper,
  pkg-config,
  bash,
  coreutils,
  ethtool,
  gawk,
  gnugrep,
  imagemagick,
  iproute2,
  killall,
  libev,
  libuuid,
  mount,
  nftables,
  openvswitch,
  procps,
  tcpdump,
  umount,
  ospf-mdr,
  emane,
  hostname,
  frr,
  # Python Dependencies
  python3,
  invoke,
  lxml,
  Mako,
  Fabric,
  poetry-core,
  pyproj,
  protobuf,
  pillow,
  pyyaml,
  netaddr,
  grpcio,
  grpcio-tools,
  tkinter,
  # Services
  bird,
  openssh,
  olsrd,
  openvpn,
  at,
  vsftpd,
  radvd,
  iptables,
  # Docs
  withDocs ? true,
  help2man,
  sphinx,
  sphinx-rtd-theme,
  # Docker
  withDocker ? true,
  docker-client,
  # Testing
  nixosTests,
  pytest,
  mock,
}: let
  inherit (gitignore.lib) gitignoreSource;
in
  buildPythonPackage rec {
    pname = "core";
    version = "8.2.0";
    format = "pyproject";
    disabled = !isPy3k;

    src = gitignoreSource ../.;

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
        makeWrapper
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
      hostname
    ];

    pythonRelaxDeps = ["fabric" "grpcio" "invoke" "lxml" "mako" "netaddr" "pillow" "protobuf" "pyproj" "pyyaml"];
    propagatedBuildInputs = [
      invoke
      lxml
      Mako
      Fabric
      poetry-core
      pyproj
      protobuf
      pillow
      pyyaml
      netaddr
      grpcio
      grpcio-tools
      tkinter
      emane
    ];

    postPatch = ''
      substituteInPlace daemon/pyproject.toml \
        --replace 'build-backend = "poetry.masonry.api"' 'build-backend = "poetry.core.masonry.api"'

      # Fix EMANE paths
      substituteInPlace daemon/core/emane/emanemanager.py --replace "/usr" "${emane}"
      substituteInPlace daemon/core/emulator/coreemu.py --replace "/usr" "${emane}"
      substituteInPlace daemon/core/xml/emanexml.py --replace "/usr" "${emane}"
      substituteInPlace daemon/core/gui/data/xmls/*.xml --replace "/usr" "${emane}"

      # Fix Service Paths
      substituteInPlace daemon/core/configservices/frrservices/services.py \
        --replace "/usr/local/bin /usr/bin /usr/lib/frr" "${frr}/bin" \
        --replace "/usr/local/sbin /usr/sbin /usr/lib/frr" "${frr}/libexec/frr"

      substituteInPlace daemon/core/configservices/quaggaservices/services.py \
        --replace "/usr/local/bin /usr/bin /usr/lib/quagga" "${ospf-mdr}/bin" \
        --replace "/usr/local/sbin /usr/sbin /usr/lib/quagga" "${ospf-mdr}/libexec/quagga"
    '';

    buildPhase = ''
      make

      pushd daemon
      runHook pipBuildPhase
      runHook pipWheelPhase
      mv dist ../
      popd

      mkdir -p $out/share/core/
      cp dist/*.whl $out/share/core/
    '';

    toolPaths = lib.makeBinPath (
      [
        bash
        nftables
        iproute2
        ethtool
        libuuid
        mount
        procps
        umount
        ospf-mdr
        emane
        hostname

        # Service Dependencies
        bird
        openssh
        olsrd
        openvswitch
        frr
        openvpn
        at
        vsftpd
        radvd
        iptables
        killall
        tcpdump
      ]
      ++ (lib.lists.optional withDocker docker-client)
    );

    installPhase = ''
      make install
      runHook pipInstallPhase

      install -Dm755 daemon/scripts/* -t $out/bin

      wrapProgram $out/bin/core-cleanup \
        --prefix PATH : ${lib.makeBinPath [procps gnugrep coreutils killall iproute2 gawk nftables]}

      wrapProgram $out/bin/core-daemon \
        --prefix PATH : ${toolPaths} \
        --prefix PATH : "${ospf-mdr}/libexec/quagga"

      wrapProgram $out/bin/core-route-monitor --prefix PATH : ${lib.makeBinPath [tcpdump]}

      mkdir -p $out/etc/core
      cp daemon/data/*.conf $out/etc/core/
    '';

    checkInputs = [pytest mock];
    checkPhase = ''
      substituteInPlace daemon/tests/conftest.py --replace '"emane_prefix": "/usr"' '"emane_prefix": "${emane.out}"'

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
