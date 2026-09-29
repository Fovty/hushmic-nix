{
  lib,
  rustPlatform,
  fetchFromGitHub,
  fetchurl,
  makeWrapper,
  patchelf,
  pkg-config,
  onnxruntime,
  pipewire,
  libGL,
  libxkbcommon,
  wayland,
  xorg,
}:

let
  model8 = fetchurl {
    url = "https://huggingface.co/Ceva-IP/DPDFNet/resolve/main/onnx/dpdfnet8_48khz_hr.onnx?download=true";
    hash = "sha256-ezr7smCgj+mvPRbjvamSlxvh5+lR0d7nwtI19cQ/VjE=";
  };
  model2 = fetchurl {
    url = "https://huggingface.co/Ceva-IP/DPDFNet/resolve/main/onnx/dpdfnet2_48khz_hr.onnx?download=true";
    hash = "sha256-fwV1pc7Auk/9j4vWV+BtAH5MzdlV12+quSK50ykdwUs=";
  };
  # Native engine weights (HushMic >= 0.10): upstream, from the DPDFNet
  # commit the C runtime in hushmic-denoiser is vendored from, with the copy
  # attached to the HushMic v0.10.0 release as a fallback. Pinned by hash,
  # so nix-update never has to touch them.
  dpdfnetNative = "https://raw.githubusercontent.com/ceva-ip/DPDFNet/6a5dbd3ea5dbea88c30a2be8e7c689b5eb26b533/native_inference/artifacts/v1";
  weightsMirror = "https://github.com/Fovty/hushmic/releases/download/v0.10.0";
  weights8 = fetchurl {
    urls = [
      "${dpdfnetNative}/dpdfnet8_48khz_hr/weights.f32"
      "${weightsMirror}/dpdfnet8_48khz_hr.weights.f32"
    ];
    hash = "sha256-Wlu2eoYZCQxU3CeTU2/oE/44EjsjbURfNDOq/jB1Up0=";
  };
  weights2 = fetchurl {
    urls = [
      "${dpdfnetNative}/dpdfnet2_48khz_hr/weights.f32"
      "${weightsMirror}/dpdfnet2_48khz_hr.weights.f32"
    ];
    hash = "sha256-y3JIuPzL/3sy8lTsLtAGHmBFFLLM2Y2ZfNCBqHZCTns=";
  };
  guiLibs = [
    libGL
    libxkbcommon
    wayland
    xorg.libX11
    xorg.libXcursor
    xorg.libXi
    xorg.libXrandr
    xorg.libxcb
  ];
in
rustPlatform.buildRustPackage rec {
  pname = "hushmic";
  version = "0.10.1";

  src = fetchFromGitHub {
    owner = "Fovty";
    repo = "hushmic";
    tag = "v${version}";
    hash = "sha256-oz4q8R8+xlqKnBmaVQq7NAR9kEp9qnabmSbY/vV1BDE=";
  };

  cargoHash = "sha256-efkZuhCOrrsgBAv228ElNWGQZtDBMpONjwqA5L18asM=";

  nativeBuildInputs = [ makeWrapper patchelf pkg-config ];
  buildInputs = [ onnxruntime ] ++ guiLibs;

  HUSHMIC_BUILD_MODEL = "${placeholder "out"}/share/hushmic/models/dpdfnet8_48khz_hr.onnx";
  HUSHMIC_BUILD_DYLIB = "${onnxruntime}/lib/libonnxruntime.so";

  preCheck = ''
    mkdir -p "$out/share/hushmic/models"
    ln -s ${model8} "$out/share/hushmic/models/dpdfnet8_48khz_hr.onnx"
  '';

  postInstall = ''
    install -Dm644 "$(find target -path '*/release/libdpdfnet_ladspa.so' -print -quit)" \
      "$out/lib/ladspa/libdpdfnet_ladspa.so"
    rm -f "$out/lib/libdpdfnet_ladspa.so"
    rm -f "$out/share/hushmic/models/dpdfnet8_48khz_hr.onnx"
    install -Dm644 ${model8} "$out/share/hushmic/models/dpdfnet8_48khz_hr.onnx"
    install -Dm644 ${model2} "$out/share/hushmic/models/dpdfnet2_48khz_hr.onnx"
    install -Dm644 ${weights8} "$out/share/hushmic/models/dpdfnet8_48khz_hr.weights.f32"
    install -Dm644 ${weights2} "$out/share/hushmic/models/dpdfnet2_48khz_hr.weights.f32"
    install -Dm644 packaging/hushmic.desktop "$out/share/applications/hushmic.desktop"
    install -Dm644 packaging/hushmic-256.png "$out/share/icons/hicolor/256x256/apps/hushmic.png"

    # Branded tray STATUS icons: the SNI tray requests these by theme name
    # (hushmic-tray / -off / -error) in the hicolor "status" context. Without
    # them the tray falls back to the app logo and never switches state.
    for size in 16x16 22x22 24x24 32x32 48x48 64x64 128x128 256x256; do
      for icon in hushmic-tray hushmic-tray-off hushmic-tray-error; do
        install -Dm644 "packaging/tray/hicolor/$size/status/$icon.png" \
          "$out/share/icons/hicolor/$size/status/$icon.png"
      done
    done

    wrapProgram "$out/bin/hushmic" \
      --prefix PATH : ${lib.makeBinPath [ pipewire ]} \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath guiLibs} \
      --set HUSHMIC_PLUGIN_SO "$out/lib/ladspa/libdpdfnet_ladspa.so" \
      --set HUSHMIC_MODEL_DIR "$out/share/hushmic/models" \
      --set ORT_DYLIB_PATH "${onnxruntime}/lib/libonnxruntime.so" \
      --set HUSHMIC_TRAY_THEME_DIR "$out/share/icons";
  '';

  # The in-app "Start on login" bakes current_exe() (the raw .hushmic-wrapped)
  # into the autostart Exec, bypassing the wrapper's LD_LIBRARY_PATH. The A/B
  # and About windows dlopen libEGL/wayland/xkbcommon at runtime, so on
  # autostart they fail to open. Bake the GUI libs into the ELF's RUNPATH so a
  # direct exec resolves them without the wrapper. --add-rpath appends, keeping
  # the glibc/onnxruntime entries; runs in postFixup, after wrapProgram created
  # the wrapped binary.
  postFixup = ''
    patchelf --add-rpath "${lib.makeLibraryPath guiLibs}" "$out/bin/.hushmic-wrapped"
  '';

  meta = {
    description = "Real-time microphone noise suppression as a virtual mic";
    homepage = "https://github.com/Fovty/hushmic";
    license = with lib.licenses; [ mit asl20 ];
    mainProgram = "hushmic";
    platforms = [ "x86_64-linux" ];
  };
}
