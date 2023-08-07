{
  lib,
  nix-filter,
  buildPythonPackage,
  pythonAtLeast,
  pythonRelaxDepsHook,
  poetry-core,
  grpcio-tools,
  Fabric,
  grpcio,
  invoke,
  lxml,
  Mako,
  netaddr,
  pillow,
  protobuf,
  pyproj,
  pyyaml,
  # Testing
  pytestCheckHook,
  mock,
}: let
  version = "8.2.0";
in
  buildPythonPackage {
    pname = "core";
    inherit version;
    format = "pyproject";
    disabled = !pythonAtLeast "3.6";

    src = nix-filter {
      root = ../../../daemon;
    };

    PACKAGE_VERSION = version;
    postPatch = ''
      substituteInPlace pyproject.toml \
          --replace 'build-backend = "poetry.masonry.api"' 'build-backend = "poetry.core.masonry.api"'

      substituteAll core/constants.py.in core/constants.py
    '';

    preBuild = ''
      python -m grpc_tools.protoc -I proto/ --python_out=. proto/core/api/grpc/*.proto
      python -m grpc_tools.protoc -I proto/ --grpc_python_out=. proto/core/api/grpc/core.proto
    '';

    nativeBuildInputs = [
      pythonRelaxDepsHook
      pytestCheckHook
      poetry-core
      grpcio-tools
    ];
    pythonRelaxDeps = true;

    propagatedBuildInputs = [
      Fabric
      grpcio
      invoke
      lxml
      Mako
      netaddr
      pillow
      protobuf
      pyproj
      pyyaml
    ];

    # Testing
    nativeCheckInputs = [pytestCheckHook mock];
    pythonImportsCheck = ["core"];

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
