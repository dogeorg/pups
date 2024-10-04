{ pkgs ? import <nixpkgs> {} }:

let
  dogenet_upstream = pkgs.callPackage (pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/dogeorg/dogebox-nur-packages/22e2e8041f9d857861c9b60bcefd6f0291fa5c56/pkgs/dogenet/default.nix";
    sha256 = "sha256-fSjv8kJ5VCZ5nUlZpBqmNu/sS4wLU/glinOT7Axao8A=";
  }) {};

  dogenet = pkgs.writeScriptBin "run.sh" ''
    #!${pkgs.bash}/bin/bash
    export KEY=`cat /storage/delegated.key`
    IP=`${pkgs.curl}/bin/curl https://reflector.dogecoin.org/me | ${pkgs.jq}/bin/jq -r .ip`
    cp ${dogenet_upstream}/bin/storage/dbip-city-ipv4-num.csv /storage
    ${dogenet_upstream}/bin/dogenet --handler ''${DBX_PUP_IP}:42068 --web ''${DBX_PUP_IP}:8080 --public ''${IP}:42069 --dir /storage
  '';
in
{
  inherit dogenet;
}
