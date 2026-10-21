# Third-party code

| Component | Location | License | Notes |
|---|---|---|---|
| LaiNES | `sw/nes/vendor` | BSD-2-Clause | NES core, vendored with patches |
| Buildroot | `os/` (fetched at build) | GPL-2.0 | not committed |
| Linux kernel | fetched at build | GPL-2.0 | not committed |

Original code in this repository is MIT (see `LICENSE`).

Vendored code keeps its own license. Patches to vendored code live in
`sw/nes/patches/` and are listed in `sw/nes/README.md`.
