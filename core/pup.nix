{ pkgs ? import <nixpkgs> {} }:

let
  storageDirectory = "/storage";
  dogecoind_bin = pkgs.callPackage (pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/dogeorg/dogebox-nur-packages/29193479f4c65ab0adf825e311695f9af9c1f260/pkgs/dogecoin-core/default.nix";
    sha256 = "sha256-Ook3gvhiE7Bk2E7adF6wubBMjBMK7lr98SWHMemXE6Q=";
  }) {
    disableWallet = true;
    disableGUI = true;
    disableTests = true;
  };

  dogecoind = pkgs.writeScriptBin "run.sh" ''
    #!${pkgs.stdenv.shell}
    if [ ! -f /storage/rpcuser.txt ] || [ ! -f /storage/rpcpassword.txt ]; then
        RPCUSER=dogebox_core_pup_temporary_static_username
        RPCPASS=dogebox_core_pup_temporary_static_password

        echo "$RPCUSER" > /storage/rpcuser.txt
        echo "$RPCPASS" > /storage/rpcpassword.txt
    else
        RPCUSER=$(cat /storage/rpcuser.txt)
        RPCPASS=$(cat /storage/rpcpassword.txt)
    fi
    
    ${dogecoind_bin}/bin/dogecoind \
      -port=22556 \
      -datadir=${storageDirectory} \
      -rpc=1 \
      -rpcuser=$RPCUSER \
      -rpcpassword=$RPCPASS \
      -rpcbind=$DBX_PUP_IP \
      -rpcport=22555 \
      -rpcallowip=10.69.0.0/16 \
      -zmqpubhashblock=tcp://0.0.0.0:28332
  '';

  monitor = pkgs.buildGoModule {
    pname = "monitor";
    version = "0.0.1";
    src = ./monitor;
    vendorHash = null;

    systemPackages = [ dogecoind_bin ];
    
    buildPhase = ''
      export GO111MODULE=off
      export GOCACHE=$(pwd)/.gocache
      go build -ldflags "-X main.pathToDogecoind=${dogecoind_bin}" -o monitor monitor.go
    '';

    installPhase = ''
      mkdir -p $out/bin
      cp monitor $out/bin/
    '';
  };

  logger = pkgs.buildGoModule {
    pname = "logger";
    version = "0.0.1";
    src = ./logger;
    vendorHash = null;

    buildPhase = ''
      export GO111MODULE=off
      export GOCACHE=$(pwd)/.gocache
      go build -ldflags "-X main.storageDirectory=${storageDirectory}" -o logger logger.go
    '';

    installPhase = ''
      mkdir -p $out/bin
      cp logger $out/bin/
    '';
  };
in
{
  inherit dogecoind monitor logger;
}
