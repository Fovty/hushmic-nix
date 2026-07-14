# hushmic-nix

Nix flake for [HushMic](https://github.com/Fovty/hushmic) — real-time microphone
noise suppression as a system-wide PipeWire virtual mic.

## Run

```sh
nix run github:Fovty/hushmic-nix -- --tray
```

## Install into your profile

```sh
nix profile install github:Fovty/hushmic-nix
```

> Needs flakes enabled — if Nix complains, prepend
> `--extra-experimental-features 'nix-command flakes'`.

Builds HushMic from source (required on NixOS, where the prebuilt binaries won't
run) and wires up the LADSPA plugin, the DPDFNet models, and the ONNX Runtime.
The flake tracks upstream releases automatically. Licensed MIT OR Apache-2.0,
matching upstream.
