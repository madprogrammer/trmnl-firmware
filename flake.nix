{
  description = "Build environment for TRMNL firmware (PlatformIO / ESP32)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      # PlatformIO downloads prebuilt cross-toolchains (xtensa/riscv gcc,
      # esptool, etc.) that are dynamically linked against a standard FHS
      # layout and are NOT patched for NixOS. Running everything inside an
      # FHS sandbox provides /lib/ld-linux so those binaries just work.
      mkFhs = pkgs: pkgs.buildFHSEnv {
        name = "trmnl-pio";
        targetPkgs = p: with p; [
          platformio-core   # provides the `pio` CLI
          (python3.withPackages (ps: with ps; [ pyserial ]))  # pyserial for serial-monitor scripts
          git
          which
          # runtime libs the downloaded toolchains link against:
          zlib
          libusb1
          systemd           # libudev, for serial/USB device access
          ncurses
          stdenv.cc.cc.lib  # libstdc++ / libgcc_s
        ];
        runScript = "bash";
        profile = ''
          export PLATFORMIO_CORE_DIR="$HOME/.platformio"
          echo "TRMNL PlatformIO shell (FHS). Examples:"
          echo "  pio run -e seeed_xiao_esp32s3          # build an existing env"
          echo "  pio run -e <env> -t upload             # build + flash"
        '';
      };
    in {
      # `nix develop` execs straight into the FHS sandbox so `pio` and the
      # toolchains it downloads all run correctly on NixOS.
      devShells = forAll (pkgs: {
        default = pkgs.mkShell {
          shellHook = "exec ${mkFhs pkgs}/bin/trmnl-pio";
        };
      });

      # `nix run` (or running the built binary) also drops you in the shell.
      packages = forAll (pkgs: {
        default = mkFhs pkgs;
      });
    };
}
