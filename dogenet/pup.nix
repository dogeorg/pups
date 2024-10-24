{ pkgs ? import <nixpkgs> {} }:

let
  dogenet_upstream = pkgs.callPackage (pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/dogeorg/dogebox-nur-packages/0fe8f2bb6d1fb842f51145d87adb04d89e81046a/pkgs/dogenet/default.nix";
    sha256 = "sha256-7AvXs1EUt66qiddSuVzVMEn0JZWmcObhRtEIEKcdQyE=";
  }) {};

  dogenet = pkgs.writeScriptBin "run.sh" ''
    #!${pkgs.bash}/bin/bash
    export KEY=`cat /storage/delegated.key`
    IP=`${pkgs.curl}/bin/curl https://reflector.dogecoin.org/me | ${pkgs.jq}/bin/jq -r .ip`
    ${dogenet_upstream}/bin/dogenet --handler ''${DBX_PUP_IP}:42068 --web ''${DBX_PUP_IP}:8080 --public ''${IP}:42069 --dir /storage
  '';
in
{
  inherit dogenet;
}
