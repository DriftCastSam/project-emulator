# Contributing

This repository is a hardware plus software project. The rules are strict
where it matters: a bitstream that does not close timing is not done, and a
change that only works on the host is not done.

## 1. Ground rules

1. `dev` is the integration branch. `main` is release-only.
2. Everything lands through a pull request. No direct pushes to `dev`.
3. One concern per PR. Split a feature into reviewable slices.
4. Never commit build output. `hw/build/`, `os/output/`, `sw/nes/build/` are
   ignored; keep it that way.
5. Never lower a verification bar. If a test is flaky, fix it or delete the
   claim, not the test.
6. Vendored third-party code keeps its license and stays in its own directory.

## 2. Branches

| Branch | Purpose |
|---|---|
| `main` | releases only |
| `dev` | integration, default branch |
| `sff/<area>/<slug>` | feature work, branched from `dev` |
| `hotfix/<slug>` | from `main`, merged to `main` and `dev` |

Areas: `hw`, `sw`, `os`, `docs`, `infra`, `app`.

```
sff/hw/hdmi-test-pattern
sff/hw/ppu-background
sff/sw/evdev-input
sff/os/buildroot-pynq-z2
```

## 3. Commits

Conventional Commits:

```
feat(hw): add 720p timing generator
fix(sw): clip sprite Y before fetching
docs(hw): record HDMI pinout
build(os): pin Buildroot to 2026.02
```

Subject in imperative mood, no trailing period, at most 72 characters.

## 4. Pull requests

A PR is ready when:

- [ ] It states the acceptance test and how it was verified.
- [ ] RTL: `make lint` passes, new logic has a testbench, synthesis and
      implementation close timing.
- [ ] Software: `make sw` builds, relevant unit tests pass.
- [ ] OS: the defconfig builds or the failure is explained in the PR.
- [ ] No generated files, no secrets, no commented-out debug.
- [ ] Documentation updated if behavior or the register map changed.

## 5. Definition of done

- RTL: Verilator lint clean, unit testbench passes, WNS positive after
  implementation at every generated clock.
- Software: builds with the cross toolchain, runs on the board, no busy loop
  that starves the frame loop.
- Image: boots on the board, UART log attached to the PR.
- Behavior changes update `docs/architecture.md` and the ADRs.

## 6. Build environment

| Tool | Path |
|---|---|
| Vivado | `/tools/Xilinx/2025.2/Vivado` |
| Vitis | `/tools/Xilinx/2025.2/Vitis` |
| Verilator, cmake, ninja | system |
| Cross compiler | Buildroot toolchain |

Source `/tools/Xilinx/2025.2/settings64.sh` before running `vivado` or
`xsct` from a plain shell.
