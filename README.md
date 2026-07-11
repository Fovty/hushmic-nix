# hushmic-nix

A Nix flake for [HushMic](https://github.com/Fovty/hushmic), a real-time
microphone noise suppressor for PipeWire.

```console
nix run github:YOUR-USER/hushmic-nix
```

Or add the flake as an input and use `inputs.hushmic-nix.packages.${system}.default`.
HushMic requires a running PipeWire/WirePlumber session and currently supports
only x86_64 Linux, matching upstream.

The scheduled GitHub Actions updater checks daily for a new upstream release,
refreshes the source and Cargo hashes with `nix-update`, verifies the build, and
opens (or refreshes) an update pull request. It can also be started manually
from the Actions tab.
