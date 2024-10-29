{ pkgs ? import <nixpkgs> {} }:

let
  dogenet_upstream = pkgs.callPackage (pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/dogeorg/dogebox-nur-packages/c20d95a0695fdd0043e2e15d5f7967ed565e228d/pkgs/dogenet/default.nix";
    sha256 = "sha256-hJ/74OtGf4EEj+JSTplgcSc1/jX4baxOI2QPeqOoaqI=";
  }) {};

  dogenet = pkgs.writeScriptBin "run.sh" ''
    #!${pkgs.bash}/bin/bash
    KEY=`cat /storage/delegated.key` ${dogenet_upstream}/bin/dogenet --handler ''${DBX_PUP_IP}:42068 --web ''${DBX_PUP_IP}:8080 --dir /storage --reflector
  '';
in
{
  inherit dogenet;
}
