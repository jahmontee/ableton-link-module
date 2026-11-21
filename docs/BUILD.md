# Source and build

The module directory contains the editor, backend, port definitions, and the exact published module manifest. The two ARM64 libraries build from `engine-source/` and `admission-source/` using the vendored LV2 headers.

Run `sh build-arm64.sh` with the Debian GCC 12 AArch64 cross-toolchain. Then run `sha256sum -c module-binaries.SHA256SUMS` to compare both outputs with the signed release. The release uses the Hector ARM64 target.

`source-identity.json` binds this source to the signed installer. The release uses the same signed shared installer runtime and storage repairs as the tested kit. `shared/runtime-source-index.json` maps its installed file versions to their corresponding sources. Runtime source variants and decoded USB bootstraps supplied here complement the two matching public source archives.

- [Network Connection / Poly / View source archive](https://github.com/jahmontee/network-connection-poly-view/releases/download/v0.2.0-beta.1/Network-Connection-Poly-View-Hector-0.2.0-beta.1-Source.tar.gz)
- [Flash Repair corresponding source](https://github.com/jahmontee/network-connection-poly-view/releases/download/v0.2.0-beta.1/Hector-Flash-Repair-0.1.0-spi-rx.9-Source.tar)

The signed ZIP is the installation artifact. Its original contents are required for publisher verification.
