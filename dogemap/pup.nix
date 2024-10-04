{ pkgs ? import <nixpkgs> {} }:

let
  jampuppy = pkgs.callPackage (pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/dogeorg/dogebox-nur-packages/0b01b0f9a537e44d0faf105abd879ea8dfac04ca/pkgs/jampuppy/default.nix";
    sha256 = "sha256-467MLF9QKhj1ah823AUzQCL9zhMWzbIPf6bfhZqtvMw=";
  }) {};

  ui = pkgs.fetchgit {
    url = "https://github.com/dogeorg/dogemap-ui.git";
    rev = "v0.0.2";
    sha256 = "sha256-qITc1EcEYvHOeVszztd7G3l04AJfu/wzOapRokMvndk=";
  };

  dogemap = pkgs.writeScriptBin "run.sh" ''
    #!${pkgs.bash}/bin/bash
    ${jampuppy}/bin/jampuppy -A index.html --dir ${ui} --host 0.0.0.0 --port 8080 --proxy "/dogenet http://''${DBX_IFACE_DOGENET_WEB_API_HOST}:''${DBX_IFACE_DOGENET_WEB_API_PORT}/"
  '';
in
{
  inherit dogemap;
}
