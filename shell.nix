# Licensed under the Apache License, Version 2.0 or the MIT License.
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright Tock Contributors 2022.

# Shell expression for the Nix package manager
#
# This nix expression creates an environment with necessary packages installed:
#
#  * `tockloader`
#  * rust
#
# To use:
#
#  $ nix-shell
#

{ pkgs ? import <nixpkgs> {} }:

with builtins;
let
  inherit (pkgs) stdenv lib;

  # Use builtins.fromTOML if available, otherwise use remarshal to
  # generate JSON which can be read. Code taken from
  # nixpkgs/pkgs/development/tools/poetry2nix/poetry2nix/lib.nix.
  fromTOML = pkgs: builtins.fromTOML or (
    toml: builtins.fromJSON (
      builtins.readFile (
        pkgs.runCommand "from-toml"
          {
            inherit toml;
            allowSubstitutes = false;
            preferLocalBuild = true;
          }
          ''
            ${pkgs.remarshal}/bin/remarshal \
              -if toml \
              -i <(echo "$toml") \
              -of json \
              -o $out
          ''
      )
    )
  );

  pythonPackages = lib.fix' (self: with self; pkgs.python3Packages //
  {

    tockloader = buildPythonPackage rec {
      pname = "tockloader";
      version = "1.9.0";
      name = "${pname}-${version}";

      propagatedBuildInputs = [
        argcomplete
        colorama
        crcmod
        pyserial
        toml
        tqdm
        questionary
      ];

      src = fetchPypi {
        inherit pname version;
        sha256 = "sha256-7W55jugVtamFUL8N3dD1LFLJP2UDQb74V6o96rd/tEg=";
      };
    };
  });

  moz_overlay = import (builtins.fetchTarball https://github.com/mozilla/nixpkgs-mozilla/archive/master.tar.gz);
  nixpkgs = import <nixpkgs> { overlays = [ moz_overlay ]; };

  # Get a custom cross-compile capable Rust install of a specific channel and
  # build. Tock expects a specific version of Rust with a selection of targets
  # and components to be present.
  rustBuild = (
    nixpkgs.rustChannelOf (
      let
        # Read the ./rust-toolchain (and trim whitespace) so we can extrapolate
        # the channel and date information. This makes it more convenient to
        # update the Rust toolchain used.
        rustToolchain = (
          fromTOML pkgs (
            builtins.readFile ./rust-toolchain.toml
          )
        ).toolchain;
      in
        {
          channel = lib.head (lib.splitString "-" rustToolchain.channel);
          date = lib.concatStringsSep "-" (lib.tail (lib.splitString "-" rustToolchain.channel));
        }
    )
  ).rust.override {
    targets = [
      "thumbv7em-none-eabi" "thumbv7em-none-eabihf" "thumbv6m-none-eabi"
      "riscv32imac-unknown-none-elf" "riscv32imc-unknown-none-elf" "riscv32i-unknown-none-elf"
    ];
    extensions = [
      "rust-src" # required to compile the core library
      "llvm-tools-preview" # currently required to support recently added flags
    ];
  };

in
  pkgs.mkShell {
    name = "tock-dev";

    buildInputs = with pkgs; [
      # --- Toolchains ---
      rustBuild
      openocd

      # --- Convenience and support packages ---
      python3Full
      pythonPackages.tockloader

      # Required for tools/print_tock_memory_usage.py
      pythonPackages.cxxfilt


      # --- CI support packages ---
      qemu
    ];

    LD_LIBRARY_PATH="${stdenv.cc.cc.lib}/lib64:$LD_LIBRARY_PATH";

    # Instruct the Tock gnumake-based build system to not check for rustup and
    # assume all requirend tools are installed and available in the $PATH
    NO_RUSTUP = "1";

    # The defaults "objcopy" and "objdump" are wrong (stem from the standard
    # environment for x86), use "llvm-obj{copy,dump}" as defined in the makefile
    shellHook = ''
      unset OBJCOPY
      unset OBJDUMP
    '';
  }
