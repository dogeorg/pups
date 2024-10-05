{ pkgs ? import <nixpkgs> {} }:

let
  identity_upstream = pkgs.callPackage (pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/dogeorg/dogebox-nur-packages/2840c907f07133f7f79fd83e2846d490d6236214/pkgs/identity/default.nix";
    sha256 = "sha256-4Z+rVHOccoLZlgB5+YQKfKsTPAq5onALVE0BvvVhHLY=";
  }) {};

  ui = pkgs.fetchgit {
    url = "https://github.com/dogeorg/identity-ui.git";
    rev = "8853f04e4987ebb80a583a5cbd5cfa9ca34a71b5";
    hash = "sha256-dkUTCamwodnLaQnFw+9dLkOYlEiKTmUY2yH++CcQKww=";
  };

  identity = pkgs.writeScriptBin "run.sh" ''
    #!${pkgs.bash}/bin/bash
    export KEY=`cat /storage/delegated.key`
    ${identity_upstream}/bin/identity --bind ''${DBX_PUP_IP}:8099 --web ${ui}/src --dir /storage --handler ''${DBX_IFACE_DOGENET_HANDLER_HOST}:''${DBX_IFACE_DOGENET_HANDLER_PORT}
  '';
in
{
  inherit identity;
}
