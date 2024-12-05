{ pkgs ? import <nixpkgs> {} }:

let
  storageDirectory = "/storage";
  errorLogFile = "${storageDirectory}/error.log";

  # Fetch and build libdogecoin
  spvnode_bin = pkgs.callPackage (pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/dogeorg/dogebox-nur-packages/6ef13d84145c9e28868a586ddceebbba74bc6e4f/pkgs/libdogecoin/default.nix";
    sha256 = "sha256-cxKICNT/1o5drH/zLNu9v6LYEktKYMjjhU1NfynDp+g=";
  }) {};

  python3 = pkgs.python3;
  awk = pkgs.gawk;
  host = pkgs.host;

  # Create a script to generate the WIF key with lib
  generateWifScript = pkgs.writeScript "generate_wif.py" ''
    import ctypes
    import os
    import sys
    from ctypes import c_char_p, c_size_t, c_int, c_uint8, POINTER

    try:
        lib_path = "${spvnode_bin}/lib/libdogecoin.so"
        if not os.path.isfile(lib_path):
            with open("${errorLogFile}", "a") as f:
                f.write("Error: libdogecoin.so not found.\n")
            sys.exit(1)

        lib = ctypes.CDLL(lib_path)

        key_file = "${storageDirectory}/delegated.key"
        if not os.path.isfile(key_file):
            with open("${errorLogFile}", "a") as f:
                f.write("Error: delegated.key file not found.\n")
            sys.exit(1)

        with open(key_file, "r") as f:
            hex_privkey = f.read().strip()

        if len(hex_privkey) != 64:
            with open("${errorLogFile}", "a") as f:
                f.write("Error: Hex private key must be exactly 64 characters long.\n")
            sys.exit(1)

        bin_privkey = bytes.fromhex(hex_privkey)
        privkey_length = len(bin_privkey)

        bin_privkey_array = (c_uint8 * privkey_length)(*bin_privkey)

        wif = ctypes.create_string_buffer(53)
        size = c_size_t(53)

        lib.getWifEncodedPrivKey.argtypes = [POINTER(c_uint8), c_int, c_char_p, POINTER(c_size_t)]
        lib.getWifEncodedPrivKey.restype = None

        lib.getWifEncodedPrivKey(
            bin_privkey_array,
            c_int(0),  # Use c_int(1) if using testnet
            wif,
            ctypes.byref(size)
        )

        if not wif.value:
            with open("${errorLogFile}", "a") as f:
                f.write("Error: Failed to encode WIF private key.\n")
            sys.exit(1)

        print(wif.value.decode("utf-8"))

    except Exception as e:
        with open("${errorLogFile}", "a") as f:
            f.write(f"An error occurred: {e}\n")
        sys.exit(1)
  '';

  # Define the run.sh script
  spvnode = pkgs.writeScriptBin "run.sh" ''
    #!${pkgs.stdenv.shell}

    # Ensure delegated.key exists
    if [ ! -f "${storageDirectory}/delegated.key" ]; then
        echo "Error: delegated.key not found" | tee -a "${errorLogFile}"
        exit 1
    fi

    # Generate WIF private key from hex private key using Python script
    WIF=$(${python3}/bin/python3 ${generateWifScript})
    if [ -z "$WIF" ]; then
        echo "Error: WIF private key generation failed" | tee -a "${errorLogFile}"
        exit 1
    fi

    # Generate public key and P2PKH address using 'such' and log output
    ${spvnode_bin}/bin/such -c generate_public_key -p "$WIF" > "${storageDirectory}/such_output.log"
    if [ ! -s "${storageDirectory}/such_output.log" ]; then
        echo "Error: 'such' command failed to generate output" | tee -a "${errorLogFile}"
        exit 1
    fi

    # Read and extract the P2PKH address from the 'such' output using awk
    ADDRESS=$(${awk}/bin/awk '/p2pkh address:/ {print $3}' "${storageDirectory}/such_output.log")
    if [ -z "$ADDRESS" ]; then
        echo "Error: Failed to extract P2PKH address from 'such' output" | tee -a "${errorLogFile}"
        cat "${storageDirectory}/such_output.log" >> "${errorLogFile}"  # Log the full output for debugging
        exit 1
    fi

    # Wait until DNS resolves 'seed.multidoge.org'
    ${host}/bin/host -w seed.multidoge.org

    # Run spvnode with the generated address
    ${spvnode_bin}/bin/spvnode \
      -c -b -p -l \
      -a "$ADDRESS" \
      -w "${storageDirectory}/wallet.db" \
      -f "${storageDirectory}/headers.db" \
      -u "0.0.0.0:8888" \
      scan 2>&1 | tee -a "${storageDirectory}/output.log"
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
  inherit spvnode monitor logger python3 awk host;
}
