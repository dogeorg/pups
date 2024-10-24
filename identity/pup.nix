{ pkgs ? import <nixpkgs> {} }:

let
  identity_upstream = pkgs.callPackage (pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/dogeorg/dogebox-nur-packages/0fe8f2bb6d1fb842f51145d87adb04d89e81046a/pkgs/identity/default.nix";
    sha256 = "sha256-Zum9hKYNeFGphT44eCo6m0f48rztUOBdNxiFJCFT1g4=";
  }) {};

  ui = pkgs.fetchgit {
    url = "https://github.com/dogeorg/identity-ui.git";
    rev = "v0.0.1";
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
