{ pkgs ? import <nixpkgs> {} }:

let
  storageDirectory = "/storage";
  spvnode_bin = pkgs.callPackage (pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/dogeorg/dogebox-nur-packages/6ef13d84145c9e28868a586ddceebbba74bc6e4f/pkgs/libdogecoin/default.nix";
    sha256 = "sha256-cxKICNT/1o5drH/zLNu9v6LYEktKYMjjhU1NfynDp+g=";
  }) {
  };

  spvnode = pkgs.writeScriptBin "run.sh" ''
    #!${pkgs.stdenv.shell}

    # Generate a mnemonic if one doesn't exist
    if [ ! -f "${storageDirectory}/1" ]; then
        export MNEMONIC=$(${spvnode_bin}/bin/such -c generate_mnemonic | tee "${storageDirectory}/1")
    fi

    # Update the DNS to resolve seed.multidoge.org
    resolvectl dns eth0 1.1.1.1

    # Scan in continuous (-c), block mode (-b) from the latest checkpoint (-p)
    # Generate wallet with a mnemonic (-n) if one doesn't exist
    # Store wallet in wallet.db (-w) and headers in header.db (-f)
    # Connect to initial peer (-i) due to DNS
    # Enable http server on port 8888 (-u) for endpoints
    ${spvnode_bin}/bin/spvnode \
      -c -b -p -l \
      -n "$MNEMONIC" \
      -w "${storageDirectory}/wallet.db" \
      -f "${storageDirectory}/headers.db" \
      -i "192.7.117.243" \
      -u "0.0.0.0:8888" \
      scan 2>&1 | tee "${storageDirectory}/output.log"
  '';

  monitor = pkgs.buildGoModule {
    pname = "monitor";
    version = "0.0.1";
    src = ./monitor;
    vendorHash = null;

    systemPackages = [ spvnode_bin ];
    
    buildPhase = ''
      export GO111MODULE=off
      export GOCACHE=$(pwd)/.gocache
      go build -ldflags "-X main.pathToSpvnode=${spvnode_bin}" -o monitor monitor.go
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
  inherit spvnode monitor logger;
}
