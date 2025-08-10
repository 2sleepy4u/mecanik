{ pkgs ? import <nixpkgs> {} }:
  let
    overrides = (builtins.fromTOML (builtins.readFile ./rust-toolchain.toml));
    libPath = with pkgs; lib.makeLibraryPath [
      wayland
      libGL
      libxkbcommon
      fontconfig
      # load external libraries that you need in your rust project here
    ];
    
    # Windows cross-compilation packages - use your custom setup
    pkgs-cross-mingw64 = import pkgs.path {
      crossSystem = {
        config = "x86_64-w64-mingw32";
      };
    };
    
    pkgs-cross-mingw32 = import pkgs.path {
      crossSystem = {
        config = "i686-w64-mingw32";
      };
    };

    # 64-bit Windows cross compiler and libraries
    mingw_w64_cc = pkgs-cross-mingw64.stdenv.cc;
    mingw_w64 = pkgs-cross-mingw64.windows.mingw_w64;
    mingw_w64_pthreads_w_static = pkgs-cross-mingw64.windows.mingw_w64_pthreads.overrideAttrs (oldAttrs: {
      configureFlags = (oldAttrs.configureFlags or []) ++ [
        "--enable-static"
      ];
    });
    
    # 32-bit Windows cross compiler and libraries
    mingw_w32_cc = pkgs-cross-mingw32.stdenv.cc;
    mingw_w32 = pkgs-cross-mingw32.windows.mingw_w64;
    mingw_w32_pthreads_w_static = pkgs-cross-mingw32.windows.mingw_w64_pthreads.overrideAttrs (oldAttrs: {
      configureFlags = (oldAttrs.configureFlags or []) ++ [
        "--enable-static"
      ];
    });

    wine = pkgs.wineWowPackages.stable;
    
in
  pkgs.mkShell rec {
    buildInputs = with pkgs; [
      clang
      llvmPackages.bintools
      rustup
      udev
      systemd
      pkg-config
      wayland
      libGL
      libxkbcommon
      
      # Windows cross-compilation tools (both 32 and 64-bit)
      mingw_w64_cc
      mingw_w32_cc
	  mingw_w32_pthreads_w_static
	  mingw_w64_pthreads_w_static
      yq
      wine
    ];
    
    RUSTC_VERSION = overrides.toolchain.channel;
    
    # https://github.com/rust-lang/rust-bindgen#environment-variables
    LIBCLANG_PATH = pkgs.lib.makeLibraryPath [ pkgs.llvmPackages_latest.libclang.lib ];
    
    # Windows cross-compilation environment variables (64-bit)
    CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER = "${mingw_w64_cc}/bin/x86_64-w64-mingw32-gcc";
    CARGO_TARGET_X86_64_PC_WINDOWS_GNU_RUSTFLAGS = "-L native=${mingw_w64_pthreads_w_static}/lib -L native=${mingw_w64}/lib -C target-feature=+crt-static";
    
    # 32-bit Windows support (separate, clean paths)
    CARGO_TARGET_I686_PC_WINDOWS_GNU_LINKER = "${mingw_w32_cc}/bin/i686-w64-mingw32-gcc";
    CARGO_TARGET_I686_PC_WINDOWS_GNU_RUSTFLAGS = "-L native=${mingw_w32_pthreads_w_static}/lib -L native=${mingw_w32}/lib -C target-feature=+crt-static";

    # Wine runner for testing
    CARGO_TARGET_X86_64_PC_WINDOWS_GNU_RUNNER = "${wine}/bin/wine64";
    CARGO_TARGET_I686_PC_WINDOWS_GNU_RUNNER = "${wine}/bin/wine";
    
    # Cross-compilation settings
    PKG_CONFIG_ALLOW_CROSS = "1";
    
    shellHook = ''
      export PATH=$PATH:''${CARGO_HOME:-~/.cargo}/bin
      export PATH=$PATH:''${RUSTUP_HOME:-~/.rustup}/toolchains/$RUSTC_VERSION-x86_64-unknown-linux-gnu/bin/
      
      # Add cross-compiler tools to PATH
      export PATH=$PATH:${mingw_w64_cc}/bin
      export PATH=$PATH:${mingw_w32_cc}/bin
      
      echo "🦀 Rust development environment loaded!"
      echo ""
      echo "Available cross-compilation tools:"
      echo "  64-bit: ${mingw_w64_cc}/bin/x86_64-w64-mingw32-*"
      echo "  32-bit: ${mingw_w32_cc}/bin/i686-w64-mingw32-*"
      echo ""
      echo "Available targets:"
      echo "  🐧 x86_64-unknown-linux-gnu (Linux - default)"
      echo "  🪟 x86_64-pc-windows-gnu    (Windows 64-bit)"
      echo "  🪟 i686-pc-windows-gnu      (Windows 32-bit)"
      echo ""
      
      # Add Windows targets if they don't exist
      if ! rustup target list --installed | grep -q "x86_64-pc-windows-gnu"; then
        echo "Adding Windows 64-bit target..."
        rustup target add x86_64-pc-windows-gnu
      fi
      
      if ! rustup target list --installed | grep -q "i686-pc-windows-gnu"; then
        echo "Adding Windows 32-bit target..."
        rustup target add i686-pc-windows-gnu
      fi
      
      echo "Build commands:"
      echo "  cargo build                                          # Linux (default)"
      echo "  cargo build --target x86_64-pc-windows-gnu --release # Windows 64-bit"
      echo "  cargo build --target i686-pc-windows-gnu --release   # Windows 32-bit"
      echo ""
      echo "Test Windows binaries:"
      echo "  cargo run --target x86_64-pc-windows-gnu            # Run with Wine64"
      echo "  cargo run --target i686-pc-windows-gnu              # Run with Wine32"
      echo ""
      
      # Verify tools are available
      echo "Checking cross-compilation tools..."
      if command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
        echo "✓ x86_64-w64-mingw32-gcc found"
      else
        echo "✗ x86_64-w64-mingw32-gcc missing"
      fi
      
      if command -v i686-w64-mingw32-gcc >/dev/null 2>&1; then
        echo "✓ i686-w64-mingw32-gcc found"
      else
        echo "✗ i686-w64-mingw32-gcc missing"
      fi
      
      if command -v x86_64-w64-mingw32-dlltool >/dev/null 2>&1; then
        echo "✓ x86_64-w64-mingw32-dlltool found"
      else
        echo "✗ x86_64-w64-mingw32-dlltool missing"
      fi
      
      if command -v i686-w64-mingw32-dlltool >/dev/null 2>&1; then
        echo "✓ i686-w64-mingw32-dlltool found"
      else
        echo "✗ i686-w64-mingw32-dlltool missing"
      fi
      
      # Check if Slint environment variable is set
      if [ -n "$SLINT_INCLUDE_GENERATED" ]; then
        echo "Slint UI files: $SLINT_INCLUDE_GENERATED"
      fi
    '';
    
    # Add precompiled library to rustc search path (Linux only)
    RUSTFLAGS = (builtins.map (a: ''-L ${a}/lib'') [
      # add libraries here for Linux builds only
    ]);
    
    LD_LIBRARY_PATH = libPath;
    
    # Add glibc, clang, glib, and other headers to bindgen search path
    BINDGEN_EXTRA_CLANG_ARGS =
    # Includes normal include path
    (builtins.map (a: ''-I"${a}/include"'') [
      # add dev libraries here (e.g. pkgs.libvmi.dev)
      pkgs.glibc.dev
    ])
    # Includes with special directory paths
    ++ [
      ''-I"${pkgs.llvmPackages_latest.libclang.lib}/lib/clang/${pkgs.llvmPackages_latest.libclang.version}/include"''
      ''-I"${pkgs.glib.dev}/include/glib-2.0"''
      ''-I${pkgs.glib.out}/lib/glib-2.0/include/''
    ];
    
    # Uncomment if you're using Slint and have generated UI files
    # SLINT_INCLUDE_GENERATED = "./ui/gauge.slint";
  }
