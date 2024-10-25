{ pkgs ? import <nixpkgs> {} }:

let
  dogemap_upstream = pkgs.callPackage (pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/dogeorg/dogebox-nur-packages/2092edabf8a0a6d4094e9dd8d29dd695553ef5ec/pkgs/dogenet/default.nix";
    sha256 = "sha256-7AvXs1EUt66qiddSuVzVMEn0JZWmcObhRtEIEKcdQyE=";
  }) {};

  ui = pkgs.fetchgit {
    url = "https://github.com/dogeorg/dogemap-ui.git";
    rev = "v0.0.6";
    sha256 = "sha256-W1BU52P/6WM3zUhna1PWWb+of8KqZ3hY/cs9brJlmUQ=";
  };

  dogemap = pkgs.writeScriptBin "run.sh" ''
    #!${pkgs.bash}/bin/bash
    cp ${dogemap_upstream}/bin/storage/dbip-city-ipv4-num.csv /storage
    ${dogemap_upstream}/bin/dogemap --bind ''${DBX_PUP_IP}:8091 --dir /storage --web ${ui} --core ''${DBX_IFACE_CORE_NETWORK_HOST}:''${DBX_IFACE_CORE_NETWORK_PORT} --dogenet ''${DBX_IFACE_DOGENET_WEB_API_HOST}:''${DBX_IFACE_DOGENET_WEB_API_PORT} --identity ''${DBX_IFACE_IDENTITY_WEB_API_HOST}:''${DBX_IFACE_IDENTITY_WEB_API_PORT}
  '';
in
{
  inherit dogemap;
}
