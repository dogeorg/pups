{ pkgs ? import <nixpkgs> {} }:

let
  dogemap_upstream = pkgs.callPackage (pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/dogeorg/dogebox-nur-packages/66b656db989cd832ff60dd5b10cc58cd6e73436f/pkgs/dogemap/default.nix";
    sha256 = "sha256-+VS5EeEBPYfdCwqsIhFYLPpeRs1jTKmBwIFcQ/l+0O8=";
  }) {};

  ui = pkgs.fetchgit {
    url = "https://github.com/dogeorg/dogemap-ui.git";
    rev = "v0.0.8";
    sha256 = "sha256-3qMLsjVD19ZAMTDo6eIkwn87vExw6V6/kQncRg4H4ek=";
  };

  dogemap = pkgs.writeScriptBin "run.sh" ''
    #!${pkgs.bash}/bin/bash
    cp ${dogemap_upstream}/bin/storage/dbip-city-ipv4-num.csv /storage
    KEY=`cat /storage/delegated.key` ${dogemap_upstream}/bin/dogemap --bind ''${DBX_PUP_IP}:8080 --dir /storage --web ${ui} --core ''${DBX_IFACE_CORE_NETWORK_HOST}:''${DBX_IFACE_CORE_NETWORK_PORT} --dogenet ''${DBX_IFACE_DOGENET_WEB_API_HOST}:''${DBX_IFACE_DOGENET_WEB_API_PORT} --identity ''${DBX_IFACE_IDENTITY_WEB_API_HOST}:''${DBX_IFACE_IDENTITY_WEB_API_PORT}
  '';
in
{
  inherit dogemap;
}
