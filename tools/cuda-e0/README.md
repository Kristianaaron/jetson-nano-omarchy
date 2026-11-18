# CUDA feasibility desk checks E0a–E0d

These scripts prepare local source trees and package contents for four desk checks before any board work.
E0a compares ioctl numbers, directions, magic values, and struct sizes in R32 and R36 headers. E0b records the GLIBC symbol versions, shared-library dependencies, and `/dev`, `/sys`, and `/proc` strings embedded in the R32 libraries. E0c searches available R32, R35, and R36 `libcuda` files for GM20B and Maxwell markers, using the R32 library as a control. E0d checks whether CUDA 10.2 tools can inspect or assemble CUDA 12 cubin and PTX output for `sm_53`.

Run on the Jetson Nano or another compatible aarch64 Arch Linux system with bash, Python 3, git, curl, zstd, bsdtar, sha256sum, gcc, readelf, and strings available. The scripts do not compile or execute CUDA code on the Mac.

```bash
tools/cuda-e0/fetch.sh [WORKDIR]
tools/cuda-e0/run-e0.sh [WORKDIR] [REPORT_DIR]
```

`WORKDIR` defaults to `$HOME/cuda-e0`. Fetching is repeatable and skips already cloned repositories, downloaded archives, and extracted package trees. Each fetched package archive is checked against its published SHA256. Some R35/R36 package feeds or CUDA compatibility packages may be unavailable; those are reported and skipped. R32 CUDA library and core packages are required. `REPORT_DIR` defaults to `./results/cuda` relative to the current directory. Run the second command from the repository root to use that default.

The reports are `E0a-ioctl-diff.md`, `E0b-userspace-needs.md`, `E0c-libcuda-maxwell.md`, and `E0d-cubin.md`. Intermediate JSON, generated C sizing programs, sizes, package lists, and command output are written under `WORKDIR/out/`. The generated `.sizes.cmd` files are run with gcc by `run-e0.sh`, so their struct-size reports are produced on the target architecture. A gcc failure is saved in the matching `.sizes.err` file and the remaining checks continue. E0d records command lines, exit codes, stdout, and stderr. Its findings describe tool acceptance only; they do not establish runtime compatibility.

The static parser fixture can be checked on a development host with:

```bash
python3 tools/cuda-e0/test_ioctl_table.py
```
