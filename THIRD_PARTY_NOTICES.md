# Third-party notices

ColdSigner v0.1 pins its direct Swift dependencies and records all resolved transitive packages in [`docs/SBOM-v0.1.json`](docs/SBOM-v0.1.json). The upstream license files remain authoritative.

| Component | Version / revision | License | Source |
|---|---|---|---|
| bdk-swift and bdkFFI | 3.0.0 / `5bc9c3cddf203f6aa147d77364782bf095e4f84e` | MIT or Apache-2.0 | <https://github.com/bitcoindevkit/bdk-swift> |
| URKit | 9.0.0 / `4323721f7f91331d8cfa64ee54cfbaba106a5b20` | BSD-2-Clause-Patent | <https://github.com/BlockchainCommons/URKit> |
| WolfBase | 5.3.1 / `d7219c703316956c42a7f47f926a442d082f043f` | MIT | <https://github.com/wolfmcnally/WolfBase> |
| swift-algorithms | 1.2.1 / `87e50f483c54e6efd60e885f7f5aa946cee68023` | Apache-2.0 | <https://github.com/apple/swift-algorithms> |
| swift-numerics | 1.1.1 / `0c0290ff6b24942dadb83a929ffaaa1481df04a2` | Apache-2.0 | <https://github.com/apple/swift-numerics> |
| zlib (`libz`) | Apple platform SDK | zlib | Apple platform SDK |

The bdkFFI binary artifact checksum pinned by bdk-swift 3.0.0 is `cfc94aa657c1fe118366496cc9d55f979f8e68d9130a5526c16e34ec4cc70047` (SHA-256).

ColdSigner does not remove or replace any upstream notice. A release archive must include this file, the MIT project license, both `Package.resolved` files, and the SBOM.
