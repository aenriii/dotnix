# librepods rust rewrite (linux/rust branch), packaged without crane.
# nixpkgs' librepods is the older Qt client; this tracks the branch where
# linux development is actually happening.
{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  dbus,
  libpulseaudio,
  alsa-lib,
  bluez,
  expat,
  fontconfig,
  freetype,
  libGL,
  libX11,
  libXcursor,
  libXi,
  libXrandr,
  wayland,
  libxkbcommon,
  vulkan-loader,
}:

let
  # iced/winit dlopen these at runtime, so they go in RPATH
  # (an LD_LIBRARY_PATH wrapper like upstream's flake would also work)
  runtimeLibs = [
    libGL
    libX11
    libXcursor
    libXi
    libXrandr
    wayland
    libxkbcommon
    vulkan-loader
  ];
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "librepods";
  version = "0.1.0-unstable-2026-05-15";

  src = fetchFromGitHub {
    owner = "librepods-org";
    repo = "librepods";
    rev = "672e65ad36eebf21ff1c1a508066f9197ee56d17"; # linux/rust
    hash = "sha256-EuIYvBqBtpgutVqPOLIO3E9OhVzQ5q5TDoz/F+9MHEE=";
  };

  sourceRoot = "${finalAttrs.src.name}/linux-rust";

  # copied from linux-rust/Cargo.lock at the pinned rev; refresh it when bumping
  cargoLock.lockFile = ./Cargo.lock;

  strictDeps = true;
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [
    dbus
    libpulseaudio
    alsa-lib
    bluez
    expat
    fontconfig
    freetype
  ] ++ runtimeLibs;

  doCheck = false;

  postInstall = ''
    install -Dm644 assets/me.kavishdevar.librepods.desktop \
      $out/share/applications/me.kavishdevar.librepods.desktop
    install -Dm644 assets/icon.png \
      $out/share/icons/hicolor/256x256/apps/me.kavishdevar.librepods.png
  '';

  postFixup = ''
    patchelf --add-rpath ${lib.makeLibraryPath runtimeLibs} $out/bin/librepods
  '';

  meta = {
    description = "AirPods liberated from Apple's ecosystem (rust rewrite)";
    homepage = "https://github.com/librepods-org/librepods/tree/linux/rust";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "librepods";
  };
})
