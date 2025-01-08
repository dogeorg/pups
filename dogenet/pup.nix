{ pkgs ? import <nixpkgs> {} }:

let
  dogenet_upstream = pkgs.callPackage (pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/dogeorg/dogebox-nur-packages/66b656db989cd832ff60dd5b10cc58cd6e73436f/pkgs/dogenet/default.nix";
    sha256 = "sha256-y00U9TQx7QguxTI2x5uzVqBM43dIK8cNaMrQXsVMIZs=";
  }) {};

  dogenet = pkgs.writeScriptBin "run.sh" ''
    #!${pkgs.bash}/bin/bash
    KEY=`cat /storage/delegated.key` ${dogenet_upstream}/bin/dogenet --handler ''${DBX_PUP_IP}:42068 --web ''${DBX_PUP_IP}:8080 --dir /storage --reflector
  '';
in
{
  inherit dogenet;
}
