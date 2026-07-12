{
  lib,
  rustPlatform,
  fetchFromGitHub,
  fetchurl,
  makeWrapper,
  onnxruntime,
  pipewire,
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
in
rustPlatform.buildRustPackage rec {
  pname = "hushmic";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "Fovty";
    repo = "hushmic";
    tag = "v${version}";
    hash = "sha256-lkEjGdcAPsg9tRnh/RxDoiOww3eQPdey22QbCXmuA00=";
  };

  cargoHash = "sha256-P5nxiItJ8cR/JQJTnEEVuPDtQ2l4+ZEnaG2mi0bdwP4=";

  nativeBuildInputs = [ makeWrapper ];

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
    install -Dm644 packaging/hushmic.desktop "$out/share/applications/hushmic.desktop"
    install -Dm644 packaging/hushmic-256.png "$out/share/icons/hicolor/256x256/apps/hushmic.png"

    wrapProgram "$out/bin/hushmic" \
      --prefix PATH : ${lib.makeBinPath [ pipewire ]} \
      --set HUSHMIC_PLUGIN_SO "$out/lib/ladspa/libdpdfnet_ladspa.so" \
      --set HUSHMIC_MODEL_DIR "$out/share/hushmic/models" \
      --set ORT_DYLIB_PATH "${onnxruntime}/lib/libonnxruntime.so"
  '';

  meta = {
    description = "Real-time microphone noise suppression as a virtual mic";
    homepage = "https://github.com/Fovty/hushmic";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "hushmic";
    platforms = [ "x86_64-linux" ];
  };
}
