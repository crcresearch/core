{
  lib,
  stdenv,
  fetchFromGitHub,
  autoreconfHook,
  pkg-config,
  texinfo,
  perl,
  coreutils,
  readline,
}:
stdenv.mkDerivation rec {
  pname = "ospf-mdr";
  version = "63f07596268873aeff86f252cbc27901369ad50a";

  src = fetchFromGitHub {
    owner = "USNavalResearchLaboratory";
    repo = pname;
    rev = "63f07596268873aeff86f252cbc27901369ad50a";
    sha256 = "sha256-OSCSIOMoF2dr6dNNVyw5jobaafGWY2IO3pbiJjY+xwM=";
  };

  nativeBuildInputs = [
    autoreconfHook
    pkg-config
    perl
    texinfo
  ];

  buildInputs = [
    readline
  ];

  preAutoreconf = ''
    # Create files for AutoReconf
    touch NEWS README AUTHORS ChangeLog
  '';

  preConfigure = ''
    substituteInPlace lib/Makefile.am --replace "/bin/true" "${coreutils}/bin/true"
  '';

  configureFlags = [
    "--sysconfdir=/etc/quagga"
    "--localstatedir=/var/run/quagga"
    "--sbindir=$(out)/libexec/quagga"
    "--enable-exampledir=$(out)/share/doc/quagga/examples/"
    "--enable-vtysh"
    "--enable-vty-group=quaggavty"
    "--enable-configfile-mask=0640"
    "--enable-logfile-mask=0640"
  ];

  enableParallelBuilding = true;

  meta = with lib; {
    description = "OSPF MANET Designated Routers implementation (RFCs 5614, 5243, 5838)";
    longDescription = ''
      The Open Shortest Path First-MANET Designated Router (OSPF-MDR) implementation for quagga OSPFv3 is an implementation of RFC 5614 (OSPF MDR), RFC 5243 (OSPF Database Exchange Optimization), and RFC 5838 (OSPFv3 Address Families) for efficient routing in Mobile Ad hoc Networks (MANETs).

      This software, based on the open source Quagga Routing Suite, was originally developed by Richard Ogier and Boeing Phantom Works, and is now being maintained by the Mobile Routing project at the NRL.
    '';
    homepage = "https://www.nrl.navy.mil/Our-Work/Areas-of-Research/Information-Technology/NCS/OSPF-MANET/";
    license = licenses.gpl2;
    platforms = platforms.unix;
    maintainers = with maintainers; [];
  };
}
