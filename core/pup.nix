{ pkgs ? import <nixpkgs> {} }:

let
  storageDirectory = "/storage";
  dogecoind_bin = pkgs.callPackage (pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/dogeorg/dogebox-nur-packages/abd8d08e052599b1d17976b5317eb9acdc2f51d8/pkgs/dogecoin-core/default.nix";
    sha256 = "sha256-ZG4Xa/ChHBxpsXN+n49xy3s5W0hOAELs4m1HZdn5GlQ=";
  }) {
    disableWallet = true;
    disableGUI = true;
    disableTests = true;
    enableZMQ = true;
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
      -rpcallowip=0.0.0.0/0 \
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
