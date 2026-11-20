# CUDA on the Jetson Nano with a mainline kernel: research and experiment plan

- Date: 2026-11-18
- Board: Jetson Nano 4GB (P3450, Tegra X1 / T210, GM20B Maxwell, SM 5.3)
- Target stack: Omarchy (Arch Linux ARM, Hyprland), mainline kernel 7.2.x, nouveau + tegra-drm,
  patched Mesa 26.2.x
- Method: public sources only, read on the web. No device access, no ssh, nothing run. Every factual
  claim has a source number `[n]` from the list at the end. Claims marked **INFERRED** are our own
  reasoning from those sources and are not proven.
- Framing: this is a research and experiment project. Where a route looks blocked, section 8 turns
  the blocker into a test.

## Summary

**(a) CUDA 12 through NVIDIA's own driver: no-go on current evidence.** NVIDIA has published no
libcuda newer than CUDA 10.2 for GM20B. Staff said there is no plan for CUDA 11 on Nano, TX1 or TX2
[3][4]. JetPack 4.6.6 / R32.7.6 is the final release for the Nano [6]. There is one open lead, and
it changes the picture for the kernel side. NVIDIA's current nvgpu source, the R36 tree built
out-of-tree for kernel 5.15 and later, still contains the full GM20B HAL and the
`nvidia,tegra210-gm20b` platform entry [9][10][11]. Nobody has published a test of whether an
Orin-era libcuda (CUDA 11.4 to 12.x) still carries Maxwell code. Experiment E0c settles that without
hardware. The CUDA 12 *compiler* still emits sm_53 code; CUDA 13.0 removed Maxwell [19]. So "CUDA 12
source code running on this GPU" is a set of experiments (E8), not a closed door.

**(b) CUDA 10.2 next to Omarchy on a mainline kernel: unproven, plausible, high effort.** We found
no public report of nvgpu or CUDA running on any T210 board with a kernel newer than 4.9 [12][13][14].
The best starting point is the R36 nvgpu tree, not the R32 one. In R36, Tegra-only dependencies
(DVFS, EMC bandwidth manager, MC flush) sit behind `#ifdef`s. The tree uses kernel-version checks,
and it talks to the **upstream** host1x driver through a shim [10][11][17][18]. The R32 tree is
written against 4.9-only APIs [15][16]. Rough effort is 8 to 16 engineer-weeks to reach `deviceQuery`
(**INFERRED**). The main risks are:
- R32 libcuda may not work with the R36 kernel driver's ioctls.
- T210 power, clock and reset plumbing is missing in mainline.
- GM20B secure-boot firmware handling.
- Sharing the GPU with nouveau.

**(c) Best non-CUDA compute route: OpenGL 4.3 compute shaders on nouveau (most mature).** Next are
Mesa rusticl OpenCL on nouveau and NVK Vulkan. Mesa docs list rusticl's nouveau backend as
"supported" but not enabled by default [22][23]. NVK on Tegra is gated off on purpose ("Tegra is not
currently supported") but can be forced with an environment variable [21]. All three run on the
stack the board already has, so the cheapest real number comes from measuring them first (E1).

## 1. Is there any libcuda or driver for GM20B newer than CUDA 10.2?

**Answer: no public NVIDIA build exists. Confidence: high for "nothing published", medium for
"nothing could work" (see E0c).**

- NVIDIA staff, 2021: "CUDA 11 is integrated into our next major release. But unfortunately, Nano
  doesn't in the support range." [3]
- NVIDIA staff (dusty_nv), August 2023: "no there is not planned to be an upgrade to CUDA 11 for
  Jetson Nano/TX1/TX2." [4]
- NVIDIA staff, May 2023, on CUDA 11 on Nano: "It won't work." Jetson CUDA packages on the CUDA site
  start at 11.8 and target JetPack 5 [5].
- JetPack 5 (R35) supports only AGX Xavier, Xavier NX and Orin [1]. R36 supports only Orin [2].
- JetPack 4.6.6 / Jetson Linux R32.7.6 (22 November 2024) "marks the final release for JetPack 4
  series" for Nano, TX1 and TX2 [6].
- A 2022 forum "how-to" that pointed a Nano's apt sources at the R35.1 repo did not install any R35
  driver. Only the `nvidia-jetpack` metapackage version changed, and the 4.9 kernel and R32.4.4
  packages stayed [7]. This is not evidence of CUDA 11 on a Nano.
- Switchroot (Nintendo Switch, same T210 SoC) ships Ubuntu 24.04 with NVIDIA's L4T BSP. Press
  reports say the CUDA *runtime* works there but there is no compiler. That is the R32-era CUDA 10.x
  stack, not a newer one [24].

**The lead that is still open.** Two separate facts:

1. The R36 nvgpu tree still builds the GM20B HAL (dozens of `*_gm20b*.o` objects). Its
   `nvgpu_init_hal()` still has `case GK20A_GPUID_GM20B:` under `CONFIG_NVGPU_HAL_NON_FUSA`, which
   is set to `y` in R35's config [9][10]. `module.c` still matches `"nvidia,tegra210-gm20b"` [10].
   The same is true in R35 [8][9].
2. NVIDIA now ships user-mode CUDA as separate "forward compatibility" packages for Jetson. Example:
   `cuda-compat-orin-13-2` supplies a CUDA 13.2 `libcuda.so` "that run[s] on top of the existing
   JetPack 6 kernel driver" [20]. NVIDIA lists "Jetson boards" as a forward-compatibility platform
   [25].

So the kernel driver code for GM20B is still maintained in the tree, but the Jetson user-mode driver
is built and tested for Orin. Whether an R35 (CUDA 11.4) or R36 (CUDA 12.x) Tegra `libcuda.so`
still contains GM20B (SM 5.3) support has not been tested in public. **INFERRED:** NVIDIA likely
builds those libraries for Xavier and Orin only. But nothing we found proves the Maxwell paths were
removed. CUDA 13 dropped Maxwell entirely [19], so 12.x is the ceiling for this route in any case.

## 2. Where is the nvgpu source with GM20B, and what does it depend on?

**Answer: GPL source with GM20B exists in R32, R35 and R36 trees. Confidence: high (read in
source).**

| Tree | Kernel | Where | GM20B present |
|---|---|---|---|
| L4T R32.7.x (last Nano release) | 4.9 | NVIDIA `public_sources.tbz2` per release [26]; git mirror `OE4T/linux-tegra-4.9`, `nvidia/nvgpu/` [15] | yes, primary target |
| L4T R35.x (JetPack 5) | 5.10 | `OE4T/linux-tegra-5.10`, `nvidia/nvgpu/` [8] | yes: `hal_gm20b.c`, `tegra210-gm20b` match [8][9] |
| L4T R36.x (JetPack 6) | 5.15, built out-of-tree | `OE4T/linux-nvgpu` (mirror of `nv-tegra.nvidia.com/linux-nvgpu.git`), branch `patches-rel-36` [10] | yes: full GM20B HAL in Makefile; `gm20b_tegra_platform` in `platform_gk20a_tegra.c` [10][11] |
| R39.x (JetPack 7.2) | 6.8.12 | nvgpu exists there for Orin [27] | not checked |

Licence: nvgpu is MIT, except the Linux-specific parts, which are GPLv2 [28].

### Dependencies of the R32 (4.9) GM20B platform code [15][16]

- **Legacy nvhost.** `TEGRA_GK20A_NVHOST` depends on `TEGRA_GRHOST || TEGRA_HOST1X` [16].
  NVIDIA's own nvhost driver also gives `/dev/nvhost-ctrl` and syncpoints.
- **nvmap.** It includes `<linux/nvmap.h>` [15]. Tegra iGPU nvgpu needs both nvmap and host1x [28].
- **Tegra DVFS:**
  - `tegra_dvfs_get_rail_by_name`
  - `tegra_dvfs_is_rail_ready` and `tegra_dvfs_is_rail_up`
  - `tegra_dvfs_rail_power_up` and `tegra_dvfs_rail_power_down`
  - `tegra_dvfs_get_fmax_at_vmin_safe_t`
  - `tegra_dvfs_get_freqs`
- **EMC bandwidth manager:** `tegra_bwmgr_register`, `tegra_bwmgr_set_emc` and related calls.
- **Memory controller:** `tegra_mc_flush` and `tegra_mc_flush_done`.
- **PMC register access:** `tegra_pmc_readl` and `tegra_pmc_writel_relaxed`.
- **Thermal and power:** `tegra_soctherm_gpu_tsens_invalidate` and `tegra_edp_notify_gpu_load`.
- **Chip ID:** `tegra_get_chip_id` and `tegra_chip_get_revision` from `<soc/tegra/chip-id.h>`.
- **VPR:** the `tegra_vpr_dev` carve-out device.
- **4.9-only DMA attributes:** `<linux/dma-attrs.h>`, `DEFINE_DMA_ATTRS`.
- **Downstream headers:** a relative include of `arch/arm/mach-tegra/iomap.h`.
- **Downstream clock names:** `gpu_ref`, `pll_p_out5`, `gpu_gate`, and others.

### Dependencies of the R36 GM20B platform code [11]

The same functions are now mostly optional:

- DVFS is under `CONFIG_TEGRA_DVFS`. Without it, the railgate and unrailgate callbacks are not set.
- The bandwidth manager is under `CONFIG_TEGRA_BWMGR`.
- MC flush is under `CONFIG_NV_TEGRA_MC`.
- Fuse and chip ID are under `CONFIG_NVGPU_TEGRA_FUSE`, with a ≥4.15 path that uses the mainline
  `<soc/tegra/fuse.h>`.
- nvmap is under `CONFIG_NVGPU_NVMAP_NEXT`.
- The tree has `LINUX_VERSION_CODE` checks up to 5.10 (`qos_min_notify` / `qos_max_notify`).

Still unconditional: `<soc/tegra/pmc.h>` with `tegra_pmc_gpu_clamp_enable/disable`. **INFERRED:**
that function is not in mainline's PMC API and needs a small shim, or a powergate-based replacement.

- **R36 host1x path:** the R36 out-of-tree set (`linux-nv-oot`) has a `host1x` fork that still
  matches `nvidia,tegra210-host1x` [17]. It also has a `host1x-nvhost` shim that implements the old
  `nvhost_*` syncpoint API on top of the **upstream** host1x API [18]. The shim's own match table
  covers Tegra194 and Tegra234 only [18]. **INFERRED:** it needs T210 entries, or nvgpu can first be
  built with `CONFIG_TEGRA_GK20A_NVHOST` off, because `has_syncpoints` is set only when that config
  is on [11].
- **R36 nvmap** lives in `linux-nv-oot/drivers/video/tegra/nvmap` [29]. Whether it supports T210
  carve-outs was not checked.

Kernel versions it has been built against: 4.9 (R32), 5.10 (R35), 5.15 (R36) and 6.8 (R39, Orin)
[8][10][27]. **INFERRED:** the R36/R39 code has already been adapted to 6.x kernel APIs for Orin,
which makes a 7.2 build much smaller work than starting from R32.

## 3. Prior art: nvgpu or CUDA on a ≥5.x kernel on any T210 device

**Answer: we found none with a working nvgpu or CUDA. Confidence: medium. Absence of evidence on
public forums only.**

- **Jetson Nano forums, 2021–2024.** Users run mainline (Armbian, Fedora) with nouveau only, "no real
  GPU support, limited to nouveau" [12][13]. One user asked whether anyone had used the CUDA cores
  on an upstream kernel and got no answer [14].
- **NVIDIA's position.** No kernel upgrades on JetPack 4/5, because many drivers live only in the
  downstream kernel [30]. Moving TX2 NX from 4.9 to 5.6 or later means porting many downstream
  drivers, "with no guarantee" [31].
- **Switchroot (Nintendo Switch).** It uses the 4.9 L4T kernel (`CTCaer/switch-l4t-kernel-4.9`),
  with CUDA runtime on Ubuntu 24.04 userland [24][32]. That is prior art for **new userland on the old
  kernel**, not for nvgpu on a new kernel.
- **Mainline open stack on T210.** It is active:
  - Aaron Kling's nouveau devfreq patch for Tegra was tested on gm20b and gp10b, and reviewed in
    September 2025 [33][34].
  - A Jetson Nano 2GB device tree was under review in October 2025 [35].
  - Mainline `tegra210-p3450-0000.dts` enables `gpu@57000000` with `vdd-supply = <&vdd_gpu>` [36].
  - nouveau matches `"nvidia,gm20b"` [37].
- **Pixel C, OE4T.** Nothing found for nvgpu on ≥5.x. OE4T's R35 and R36 layers support only
  Xavier and Orin [1][2].
- **Historical open CUDA on nouveau.** Gdev implemented part of the CUDA Driver API on nouveau, for
  Fermi only, using GPU Ocelot for the runtime API [38]. It shows that an open "libcuda on nouveau"
  can be built, but nothing is current for Maxwell.

## 4. L4T R32.7 CUDA 10.2 userspace on Arch glibc, and the device nodes libcuda expects

**Answer: likely to load (glibc is backward compatible). The kernel ABI is the real blocker.
Confidence: medium.**

- R32.7 userland is built on Ubuntu 18.04 [39]. **INFERRED:** that means glibc 2.27. glibc keeps
  old symbol versions, so 2.27-linked binaries normally run on 2.4x.
- Real-world evidence of newer glibc with the R32 CUDA stack:
  - Switchroot Ubuntu 24.04 (glibc 2.39 era) reports the "CUDA runtime is present and works", on
    the 4.9 kernel [24].
  - The Qengineering Ubuntu 20.04 Nano image ships CUDA 10.2 and TensorRT 8.0.1.6+cuda10.2 [40].
- We found no report of R32 CUDA on Arch Linux ARM. **INFERRED** risks:
  - the hard-coded `/usr/lib/aarch64-linux-gnu/tegra` library path and its `ld.so.conf` entry;
  - sysfs paths the NVIDIA libraries read for chip identification, which differ on mainline;
  - `libstdc++` / `libgcc_s` mixing. A Ubuntu 18.04 chroot avoids all three for a first test (E5).
- **Device nodes.** nvgpu builds its node names from an interface name plus the suffixes `""`,
  `-as`, `-ctrl`, `-dbg`, `-prof`, `-tsg`, `-ctxsw` and `-sched` [41]. On Jetson these are:
  - `/dev/nvhost-gpu`
  - `/dev/nvhost-as-gpu`
  - `/dev/nvhost-ctrl-gpu`
  - `/dev/nvhost-dbg-gpu`
  - `/dev/nvhost-prof-gpu`
  - `/dev/nvhost-tsg-gpu`
  - `/dev/nvhost-ctxsw-gpu`
  - `/dev/nvhost-sched-gpu`

  Containers also pass `/dev/nvmap` and `/dev/nvhost-ctrl` [42][43].
- **Important finding:** the R36 nvgpu still creates the legacy names, "Special case to maintain
  legacy names": `nvhost-gpu` and `nvhost-%s-gpu`. It also creates the new `/dev/nvgpu/igpu0/*`
  tree [44]. So at the device-node level, an R32 libcuda could find an R36 kernel driver. Whether
  the ioctl structures still match is unknown. That is test E0a.

## 5. Runtime handover nouveau → nvgpu → nouveau on the same GM20B

**Answer: plausible in principle, no precedent found. Confidence: low.**

- Both drivers are platform drivers bound by device-tree compatible. nouveau matches
  `nvidia,gm20b` [37]. nvgpu matches `nvidia,tegra210-gm20b` [10]. **INFERRED:** an overlay that lists
  both compatibles, plus sysfs `unbind` / `driver_override` / `bind`, is enough to choose a driver at
  run time.
- **INFERRED risks:**
  1. GM20B uses secure boot (ACR, WPR set up as on Tegra) [45]. After nouveau unloads, falcons may
     stay in a locked state until a full GPU reset and powergate cycle. Both drivers must do that
     cycle cleanly.
  2. On this board the Hyprland desktop renders through Mesa `tegra` + nouveau. Unbinding nouveau
     takes away the 3D renderer. The desktop must first move to the existing software configuration
     (`kms_swrast`; see `docs/omarchy-on-jetson-nano.md` §6).
  3. Shared clocks, resets and the `vdd_gpu` regulator must be released by one driver before the
     other takes them.
  4. Mainline's Tegra SMMU and nvgpu's memory mappings must agree.
- We found no report of anyone switching the same Tegra iGPU between nouveau and nvgpu.

## 6. Non-CUDA GPU compute on mainline GM20B

| Route | Status in sources | Confidence |
|---|---|---|
| OpenGL 4.3+ compute shaders (Mesa nouveau `nvc0`) | nvc0 has had compute since 2013, and Maxwell reached GL 4.3 and later in 2016 [46][47]. On this board, nouveau rendering through patched Mesa 26.2.5 is already measured (`docs/omarchy-on-jetson-nano.md`). | high that it exists; not yet measured as compute here |
| OpenCL via rusticl on nouveau | Mesa docs list `nouveau` among "Supported drivers (decent support with maybe a few conformance issues or bugs)" for `RUSTICL_ENABLE`. It is not enabled by default (default build list: asahi, freedreno, panfrost, radeonsi) [22][23]. Reports of wrong output and crashes on nouveau exist [48][49]. Fine-grained SVM "mostly works fine on Nouveau, just hitting driver bugs" [50]. | medium |
| Vulkan via NVK | NVK supports Kepler and later [51]. Maxwell was enabled in April 2025 [52]. But the code has `/* Tegra is not currently supported */` in `nvk_is_conformant()`, which only lets through `NV_DEVICE_TYPE_DIS`. `NVK_I_WANT_A_BROKEN_VULKAN_DRIVER=1` overrides this. A SoC memory path exists ("On Tegra, we only have sysmem…") [21]. NVK needs Linux ≥ 6.6 [51]. | medium that it can be forced on; unknown whether it works |
| CUDA-on-other-API layers | ZLUDA targets other vendors and does not apply. chipStar compiles CUDA/HIP to SPIR-V for OpenCL or Level Zero. It needs OpenCL 2.0/3.0 with SPIR-V input, coarse-grained SVM and generic address space [53][54]. A chipStar discussion reports a rusticl-nouveau double free and SPIR-V compile segfaults [55]. | low (experiment only) |
| Open CUDA driver API on nouveau (Gdev-style) | Done before for Fermi [38]. **INFERRED:** on Maxwell it could run nvcc-built sm_53 SASS directly, with no translation, but it is a research project. | low |

## 7. Bottom line

- **(a) CUDA 12 on this board.**
  - Through NVIDIA's driver: **no-go until E0c says otherwise.** No published libcuda supports GM20B
    above 10.2.
  - CUDA 12 *source code* compiled for sm_53 is possible (CUDA 12.x still compiles Maxwell [19]).
    It can be run through the 10.2 driver (E8a, E8b) or through an open layer (E8d, E8e). Each is
    unproven.
- **(b) CUDA 10.2 next to Omarchy on a mainline kernel: conditional go as an experiment track.**
  - Port the R36 nvgpu (not R32) to 7.2. Add the nvmap and host1x pieces. Load the R32 CUDA 10.2
    userspace.
  - Rough effort: 8–16 engineer-weeks to `deviceQuery`, plus 2–4 weeks for a reliable handover with
    nouveau (**INFERRED**).
  - Main risks:
    1. R32 libcuda against R36 nvgpu/nvmap ioctls. If they do not match, fall back to porting the R32
       tree, which costs more.
    2. T210 GPU rail, clock and reset handling without downstream DVFS.
    3. Secure-boot firmware state between drivers.
    4. Zero public precedent.
- **(c) Best non-CUDA route.** Start with OpenGL compute on nouveau (proven API, already on the
  board). Then rusticl `RUSTICL_ENABLE=nouveau`. Then forced NVK. These three give the baseline
  that any CUDA route must beat.

## 8. Experiment plan (cheapest first)

The rules for every experiment:
- Nothing runs on the Mac. Builds run on an approved aarch64 build host or on the board.
- The known-good L4T card stays untouched.
- Every result goes under `results/cuda/` with the command and its raw output.

### E0. Desk checks, no hardware (hours each)

**E0a: does R32 libcuda speak the R36 nvgpu/nvmap kernel ABI?**
- Hypothesis: the R36 nvgpu keeps the legacy ioctls that R32 userspace uses. It kept the legacy node
  names [44].
- First test:
  1. Diff `include/uapi/linux/nvgpu*.h` between R32.7.4 [15] and R36 [10].
  2. Diff the nvmap ioctl header between R32 and `linux-nv-oot` [29].
  3. List every ioctl the R32 libs reference. Run `strings` / `objdump -d` on `libcuda.so`,
     `libnvrm_gpu.so` and `libnvrm_mem.so` from the R32.7.6 BSP.
- Advance: the core ioctls are unchanged in number and struct layout. Core means AS alloc, TSG open,
  channel setup / GPFIFO alloc, submit, nvmap create/alloc/mmap. Then build on R36 nvgpu.
- Kill: renumbered or removed core ioctls. Then switch to porting R32 nvgpu (E3), which costs more.

**E0b: what does R32 userspace touch?**
- Hypothesis: on a mainline system it needs only the device nodes plus a few sysfs files.
- First test:
  1. Run `readelf -V` for `GLIBC_*` symbol needs.
  2. List every `/dev/`, `/sys/` and `/proc/` string in `libcuda.so` and `libnvrm*.so`.
- Advance: glibc ≤ 2.27 symbols only, and paths we can provide.
- Kill: none expected (**INFERRED**). The output is the list of paths that E5 must provide.

**E0c: does any Orin-era Tegra libcuda still contain Maxwell / GM20B code?**
- Hypothesis: NVIDIA kept the GM20B code in its R35/R36 user-mode driver as it did in nvgpu [9][10].
- First test: in R35 `nvidia-l4t-cuda`, R36 `nvidia-l4t-cuda` and `cuda-compat-orin-12-*`
  `libcuda.so`, search for:
  - `gm20b` or `GM20B` strings;
  - SM 5.3 SASS or the `sm_53` target in the embedded JIT;
  - the Maxwell compute class ID `0xB1C0` near the class-selection code.
- Advance: Maxwell classes and the SM 5.3 back end are present. Then E8c becomes a real route to
  CUDA 11/12.
- Kill: Orin/Xavier classes only. Then CUDA 11/12 through NVIDIA's driver is closed for good.

**E0d: can the CUDA 10.2 driver load a cubin built by CUDA 12?**
- Hypothesis: SM 5.3 SASS is the same machine code. Only the ELF metadata version may differ.
- First test: build the same kernel with `nvcc 12.x -arch=sm_53 -cubin` and with 10.2. Compare
  the ELF header, `EI_ABIVERSION`, `e_flags` and `.nv.info` attributes. Feed the 12.x cubin to
  10.2's `cuobjdump` / `nvdisasm`.
- Advance: 10.2 tools parse it. Kill: format rejected. Then use the PTX route (E8b) instead.

### E1. Open compute baseline on the current board stack (0.5–2 days)

- Hypothesis: nouveau already gives usable compute on GM20B through GL, OpenCL or Vulkan.
- First test, on the Omarchy card with patched Mesa 26.2.x:
  1. GL 4.3 compute-shader SGEMM and memory-bandwidth microbenchmark. Record the renderer string.
  2. `RUSTICL_ENABLE=nouveau clinfo`, then `clpeak` and a small OpenCL CTS subset. Mesa must be
     built with `-Dgallium-rusticl=true` [23].
  3. `NVK_I_WANT_A_BROKEN_VULKAN_DRIVER=1 vulkaninfo` and a Vulkan compute SGEMM. NVK needs a Mesa
     build with the nouveau Vulkan driver and kernel ≥ 6.6 [51].
  4. Record GPU clock state for each run. nouveau devfreq for Tegra is new [33].
- Advance: correct results and a GFLOP/s and GB/s figure. This becomes the baseline every CUDA route
  must beat. Kill: wrong results or hangs. Log them as Mesa/nouveau bugs and keep the GL route.

### E2. Build the R36 nvgpu out-of-tree against mainline 7.2 (2–5 days)

- Hypothesis: the R36 tree, with GM20B left on and Tegra extras off, compiles against 7.2 with a
  small shim layer.
- First test: build `nvgpu.ko` from `OE4T/linux-nvgpu` `patches-rel-36` [10] against the board's
  7.2 headers. Use:
  - `CONFIG_TEGRA_GK20A=y` and `CONFIG_NVGPU_HAL_NON_FUSA=y`;
  - `CONFIG_TEGRA_DVFS`, `CONFIG_TEGRA_BWMGR`, `CONFIG_NV_TEGRA_MC` and `CONFIG_NVGPU_TEGRA_FUSE` all
    off;
  - `CONFIG_TEGRA_GK20A_NVHOST` off for the first pass, so no syncpoints.

  Then build `nvmap` from `linux-nv-oot` [29].
- Output: the list of missing symbols and changed APIs. Already expected from the source read:
  - `tegra_pmc_gpu_clamp_enable` / `tegra_pmc_gpu_clamp_disable`;
  - `tegra_vpr_dev`;
  - `nvhost_*` (if NVHOST is on);
  - `nvmap_dma_alloc_attrs` (if `NVMAP_NEXT`);
  - kernel APIs changed between 6.8 and 7.2 (**INFERRED**).
- Advance: it compiles with fewer than about 30 stubs or shims. Kill: deep dependence on
  downstream-only subsystems. Then compare with E3.

### E3. Only if E0a or E2 fails: build the R32 nvgpu against 7.2 (1–2 weeks of triage)

- First test: the same compile triage on the R32.7.4 tree [15].
- Already known breakage [15][16]:
  - `<linux/dma-attrs.h>` and `DEFINE_DMA_ATTRS`;
  - `<soc/tegra/chip-id.h>`;
  - `tegra_edp_*`;
  - the `mach-tegra/iomap.h` relative include;
  - the legacy `TEGRA_GRHOST` nvhost;
  - downstream `clk_get_sys` names.
- This is the fallback because it guarantees the R32 user ABI.

### E4. nvgpu probe on the board, nouveau disabled (1–3 weeks)

- Hypothesis: nvgpu can power GM20B on mainline and complete ACR and GR init.
- First test, on the spare card:
  1. Blacklist nouveau and use the software desktop config.
  2. Add a device-tree overlay that adds `nvidia,tegra210-gm20b` to `gpu@57000000` [36].
  3. Copy the R32 GM20B firmware set. **INFERRED** location: `/lib/firmware/gm20b/` in the R32
     rootfs.
  4. `insmod nvmap.ko nvgpu.ko` and capture `dmesg` with nvgpu debug.
- Advance: `gm20b detected`, ACR boot, GR init done, `/dev/nvhost-*-gpu` nodes present [10][44].
- Kill: hangs at first register access (power, clock or reset; see Thierry Reding's note [34]), or
  ACR failures that we cannot fix.

### E5. CUDA 10.2 userspace on Arch against nvgpu (days, after E4)

- Hypothesis: the R32 libs run unchanged once the nodes exist.
- First test:
  1. Run R32.7.6 `libcuda` with `deviceQuery`, `vectorAdd` and `bandwidthTest` inside an Ubuntu
     18.04 chroot.
  2. Use `strace -f` to log every open and ioctl.
  3. Run the same on Arch glibc directly.
- Advance: a correct `vectorAdd`, and `deviceQuery` shows SM 5.3 and 128 cores.
- Kill: an ioctl ABI mismatch. Then go back to E3, or shim the ioctl in nvgpu.

### E6. Runtime GPU handover (1–2 weeks, after E5)

- Hypothesis: driver-swap through sysfs works with a full GPU reset and powergate between drivers.
- First test:
  1. Stop Hyprland GPU use (swrast) and unbind nouveau.
  2. Set `driver_override=nvgpu` and bind.
  3. Run E5's tests.
  4. Unbind nvgpu and rebind nouveau.
  5. Run the E1 GL test.
  6. Repeat 20 cycles. Check `dmesg` for falcon or ACR errors.
- Advance: 20 clean cycles. Kill: falcons stay locked or the system hangs. The fallback is a reboot
  to switch, with a boot-time choice between a CUDA profile and a desktop profile.

### E7. Firmware and power hardening (1–2 weeks, after E4)

- Replace the stubbed DVFS with mainline clock and regulator calls, and add GPU devfreq.
- Measure sustained clocks against L4T on the untouched card, using the same CUDA sample.
- Advance: within 10% of L4T throughput.

### E8. CUDA 12 code on this GPU without a CUDA 12 NVIDIA driver

**E8a: CUDA 12 nvcc → sm_53 cubin → CUDA 10.2 driver API (1–3 days, after E5 and E0d).**
- Hypothesis: the driver runs SASS built by a newer toolchain if the cubin format is accepted.
- First test: load with `cuModuleLoadData` from a host program linked only to the 10.2 `libcuda`.
  Avoid `cudart` 12, which would demand a newer driver.
- Kill: the module load is rejected, or launch-parameter ABI errors.

**E8b: modern clang CUDA → PTX ISA ≤ 6.5 → 10.2 JIT (2–5 days).**
- Hypothesis: clang's NVPTX back end can target sm_53 with the 10.2 SDK. That gives modern C++
  in kernels without NVIDIA's CUDA 12 driver.
- First test: `clang++ --cuda-path=<10.2> --offload-arch=sm_53 --cuda-include-ptx=sm_53` [56].
  Run on the E5 stack.
- Kill: PTX ISA or `libdevice` mismatch that we cannot work around.

**E8c: Orin-era libcuda 11.4/12.x on R36 nvgpu with GM20B (only if E0c advances).**
- First test: R36 user libs (`libcuda`, `libnvrm_*`) on the E4 kernel driver, then `deviceQuery`
  built with CUDA 12.x for sm_53.
- Kill: a chip-ID or class check refuses GM20B.
- This is the only route to real CUDA 12 runtime support.

**E8d: open CUDA driver API on nouveau (research, months).**
- Hypothesis: a Gdev-style `libcuda` [38] on nouveau's uAPI, through Mesa's nouveau winsys, can run
  nvcc 12.x sm_53 cubins directly. Maxwell SASS is native, so there is no translation step.
- First test: launch one hand-assembled or nvcc-built sm_53 kernel through a nouveau compute
  channel from a small C program.
- Kill: the constant-bank or parameter ABI, or relocations, cannot be reproduced without NVIDIA
  documentation.

**E8e: chipStar over rusticl-nouveau (days to try).**
- Hypothesis: CUDA source → SPIR-V → rusticl nouveau runs simple kernels.
- First test: chipStar's unit tests with `RUSTICL_ENABLE=nouveau`. Check the SVM requirement
  first [53].
- Kill: the reported crashes [55] or missing SVM.

### What is unproven, stated plainly

- Nobody has published a GM20B nvgpu probe on any kernel newer than 4.9.
- Nobody has tested R32 userspace against R36 nvgpu ioctls.
- Nobody has checked Orin-era libcuda for Maxwell support.
- Nobody has published a nouveau ↔ nvgpu handover on Tegra.
- Every effort figure in this document is our own rough estimate.

## Sources

1. OE4T, JetPack 5.0.2 / L4T R35.1.0 notes: https://github.com/OE4T/meta-tegra/wiki/JetPack-5.0.2-L4T-R35.1.0-Notes
2. OE4T, JetPack 6.0 / L4T R36.3.0 notes: https://oe4t.github.io/master/release-notes/JetPack-6.0-L4T-R36.3.0-Notes.html
3. NVIDIA forum, "CUDA 11 on Jetson Nano?" (AastaLLL, 2021-08-16): https://forums.developer.nvidia.com/t/cuda-11-on-jetson-nano/186464/5
4. NVIDIA forum, "Jetson Nano with CUDA 11 and JetPack" (dusty_nv, 2023-08-18): https://forums.developer.nvidia.com/t/jetson-nano-with-cuda-11-and-jetpack-tensorflow2-compatibility/263453
5. NVIDIA forum, "Can Cuda 11 works on the jetson nano?" (AastaLLL, 2023-05-03): https://forums.developer.nvidia.com/t/can-cuda-11-works-on-the-jetson-nano-a-couple-of-contradictory-information-need-some-clarify/251997
6. NVIDIA forum, "Announcing End of Life for JetPack 4 with JetPack 4.6.6" (2024-11-22): https://forums.developer.nvidia.com/t/announcing-end-of-life-for-nvidia-jetpack-4-with-the-release-of-jetpack-4-6-6/314302
7. NVIDIA forum, "[how-to] Jetson nano, updating jetpack from 4.4.1 to 5.0.2": https://forums.developer.nvidia.com/t/how-to-jetson-nano-updating-jetpack-from-4-4-1-to-5-0-2/233738
8. OE4T linux-tegra-5.10 (R35.5), nvgpu `hal/init/` listing: https://github.com/OE4T/linux-tegra-5.10/tree/oe4t-patches-l4t-35.5.0/nvidia/nvgpu/drivers/gpu/nvgpu/hal/init
9. R35.5 nvgpu `hal_init.c`, `module.c` and `Makefile.linux.configs`:
   - https://raw.githubusercontent.com/OE4T/linux-tegra-5.10/oe4t-patches-l4t-35.5.0/nvidia/nvgpu/drivers/gpu/nvgpu/hal/init/hal_init.c
   - https://raw.githubusercontent.com/OE4T/linux-tegra-5.10/oe4t-patches-l4t-35.5.0/nvidia/nvgpu/drivers/gpu/nvgpu/os/linux/module.c
   - https://raw.githubusercontent.com/OE4T/linux-tegra-5.10/oe4t-patches-l4t-35.5.0/nvidia/nvgpu/drivers/gpu/nvgpu/Makefile.linux.configs
10. OE4T/linux-nvgpu (mirror of nv-tegra linux-nvgpu), branch `patches-rel-36`:
    - repository: https://github.com/OE4T/linux-nvgpu
    - `hal_init.c`: https://raw.githubusercontent.com/OE4T/linux-nvgpu/patches-rel-36/drivers/gpu/nvgpu/hal/init/hal_init.c
    - `module.c`: https://raw.githubusercontent.com/OE4T/linux-nvgpu/patches-rel-36/drivers/gpu/nvgpu/os/linux/module.c
    - `Makefile`: https://raw.githubusercontent.com/OE4T/linux-nvgpu/patches-rel-36/drivers/gpu/nvgpu/Makefile
    - branch list: https://github.com/OE4T/linux-nvgpu/branches/all
11. R36 `platform_gk20a_tegra.c` (contains `gm20b_tegra_platform`): https://raw.githubusercontent.com/OE4T/linux-nvgpu/patches-rel-36/drivers/gpu/nvgpu/os/linux/platform_gk20a_tegra.c
12. NVIDIA forum, "Upgrading kernel to 5+" (page 2): https://forums.developer.nvidia.com/t/upgrading-kernel-to-5/112113?page=2
13. NVIDIA forum, "Nouveau support for Jetson Nano kernel": https://forums.developer.nvidia.com/t/nouveau-support-for-jetson-nano-kernel/76577
14. NVIDIA forum, "Is anyone running a stable linux 5.15 kernel on a Jetson Nano…": https://forums.developer.nvidia.com/t/is-anyone-running-a-stable-linux-5-15-kernel-on-a-jetson-nano-or-jetson-xavier-nx/211466
15. OE4T linux-tegra-4.9 (R32.7.4), R32 `platform_gk20a_tegra.c`: https://raw.githubusercontent.com/OE4T/linux-tegra-4.9/oe4t-patches-l4t-r32.7.4/nvidia/nvgpu/drivers/gpu/nvgpu/os/linux/platform_gk20a_tegra.c
16. R32 nvgpu Kconfig: https://raw.githubusercontent.com/OE4T/linux-tegra-4.9/oe4t-patches-l4t-r32.7.4/nvidia/nvgpu/drivers/gpu/nvgpu/Kconfig
17. linux-nv-oot R36 host1x `dev.c` (matches `nvidia,tegra210-host1x`): https://raw.githubusercontent.com/OE4T/linux-nv-oot/patches-rel-36/drivers/gpu/host1x/dev.c
18. linux-nv-oot R36 `host1x-nvhost/nvhost.c` (nvhost API over upstream host1x): https://raw.githubusercontent.com/OE4T/linux-nv-oot/patches-rel-36/drivers/gpu/host1x-nvhost/nvhost.c
19. NVIDIA CUDA Features Archive (Maxwell/Pascal/Volta offline compilation removed in 13.0): https://docs.nvidia.com/cuda/cuda-features-archive/index.html ; Tom's Hardware: https://www.tomshardware.com/pc-components/gpus/nvidia-to-drop-cuda-support-for-maxwell-pascal-and-volta-gpus-with-the-next-major-toolkit-release
20. cuda-compat-orin-13-2 write-up (third-party): https://hackmd.io/@johnnynunez/r1IJZXTqWg.md
21. Mesa 26.2.6 `nvk_physical_device.c` (Debian sources): https://sources.debian.org/data/main/m/mesa/26.2.6-1/src/nouveau/vulkan/nvk_physical_device.c
22. Mesa environment variables (`RUSTICL_ENABLE` supported drivers): https://docs.mesa3d.org/envvars.html
23. Mesa 26.2.6 `meson.options` (`gallium-rusticl`, `gallium-rusticl-enable-drivers`): https://sources.debian.org/data/main/m/mesa/26.2.6-1/meson.options
24. OMG! Ubuntu, "Ubuntu 24.04 on Nintendo Switch" (CUDA runtime present and works): https://www.omgubuntu.co.uk/2024/05/ubuntu-24-04-nintendo-switch ; GameBrew: https://www.gamebrew.org/wiki/L4T_Ubuntu_Noble_Switch
25. NVIDIA CUDA Forward Compatibility (applies to "Jetson boards"): https://docs.nvidia.com/deploy/cuda-compatibility/latest/forward-compatibility.html
26. NVIDIA Jetson Linux R32.7.6 release page: https://developer.nvidia.com/embedded/linux-tegra-r3276
27. NVIDIA forum, BTF on R36.5 and R39.2.1 (kernel 6.8.12) without losing nvgpu: https://forums.developer.nvidia.com/t/enabling-config-debug-info-btf-y-on-l4t-r36-5-and-r39-2-1-without-losing-nvgpu/383803
28. threedots.ovh, "NVIDIA's open-source drivers" (nvgpu chips, licence, nvmap/host1x dependency): https://threedots.ovh/blog/?p=417
29. linux-nv-oot R36 `drivers/video/tegra/` (nvmap, host): https://github.com/OE4T/linux-nv-oot/tree/patches-rel-36/drivers/video/tegra
30. NVIDIA forum threads on Nano kernel upgrades (staff: no kernel upgrades on JetPack 4/5, drivers live in the downstream kernel): https://forums.developer.nvidia.com/t/jetson-nano-kernel-upgrade/233557 ; https://forums.developer.nvidia.com/t/compatibility-and-dependencies-with-linux-5-10/228605
31. NVIDIA forum, TX2 NX kernel 4.9 → 5.6+: https://forums.developer.nvidia.com/t/upgrade-kernel-version-on-jetson-tx2-nx-from-4-9-x-to-5-6-and-up-jetpack-4-6-r32-6-1/288631
32. CTCaer/switch-l4t-kernel-4.9 releases: https://github.com/CTCaer/switch-l4t-kernel-4.9/releases
33. patchew, "[PATCH v2] drm/nouveau: Support devfreq for Tegra": https://patchew.org/linux/20250906-gk20a-devfreq-v2-1-0217f53ee355@gmail.com ; merged commit mirror: https://mirrors.lzu.edu.cn/git/linux-nf/-/commit/6ca1701cecdb2dee487d7875e4b365029938abcf
34. LKML, Re: devfreq for Tegra (Kling and Reding, 2025-09): https://lkml.iu.edu/2509.1/07682.html
35. LKML, Jetson Nano 2GB DT review (2025-10): https://lkml.iu.edu/2510.3/06059.html
36. Mainline `tegra210-p3450-0000.dts`: https://github.com/torvalds/linux/blob/master/arch/arm64/boot/dts/nvidia/tegra210-p3450-0000.dts
37. Mainline `nouveau_platform.c` (`nvidia,gm20b` match): https://github.com/torvalds/linux/blob/master/drivers/gpu/drm/nouveau/nouveau_platform.c
38. Gdev (open CUDA driver API on nouveau, Fermi): https://github.com/shinpei0208/gdev
39. NVIDIA forum, L4T 32.7.x on Ubuntu 20.04 (sample rootfs is 18.04): https://forums.developer.nvidia.com/t/does-l4t-32-7-4-support-ubuntu-focal-fossa-20-04/270677
40. Qengineering Jetson Nano Ubuntu 20 image README: https://github.com/Qengineering/Jetson-Nano-Ubuntu-20-image/blob/main/README.md
41. R32 nvgpu `os/linux/ioctl.c` (node suffixes): https://raw.githubusercontent.com/OE4T/linux-tegra-4.9/oe4t-patches-l4t-r32.7.4/nvidia/nvgpu/drivers/gpu/nvgpu/os/linux/ioctl.c
42. NVIDIA forum, "/dev resource documentation" (nvhost-ctrl-gpu, nvmap; l4t.csv): https://forums.developer.nvidia.com/t/dev-resource-documentation/195977
43. NVIDIA forum, JetPack 5.0 DP privileged container (nvhost-as-gpu, nvhost-ctrl-gpu): https://forums.developer.nvidia.com/t/error-running-privileged-l4t-containers-with-the-nvidia-runtime-on-jetpack-5-0-developer-preview/211108/10
44. R36 nvgpu `os/linux/ioctl.c` (legacy `nvhost-%s-gpu` names kept): https://raw.githubusercontent.com/OE4T/linux-nvgpu/patches-rel-36/drivers/gpu/nvgpu/os/linux/ioctl.c
45. Nouveau list, "Improve GK20A and introduce GM20B support" (secure boot needed on released devices): https://lists.freedesktop.org/archives/nouveau/2015-June/021255.html
46. mesa-commit, "nvc0: implement compute support for nvc0" (2013): https://lists.freedesktop.org/archives/mesa-commit/2013-August/044516.html
47. GamingOnLinux, nvc0 reaches OpenGL 4.5 (2016): https://www.gamingonlinux.com/2016/10/looks-like-mesa-has-hit-opengl-45-for-the-open-source-nvidia-nvc0-driver/page=1/ ; Phoronix Maxwell nvc0: https://www.phoronix.com/review/nouveau-maxwell-pipeline
48. Mesa issue 10042, opencl-jpeg-encoder grey output on nouveau/rusticl: https://gitlab.freedesktop.org/mesa/mesa/-/issues/10042
49. pixls.us, darktable OpenCL with nouveau (crash; Zink suggested): https://discuss.pixls.us/t/darktable-opencl-with-nouveau-driver/42963
50. Mesa MR 19712, "Rusticl: fine-grained system SVM support": https://gitlab.freedesktop.org/mesa/mesa/-/merge_requests/19712
51. Mesa NVK docs (Kepler and later; Linux ≥ 6.6): https://docs.mesa3d.org/drivers/nvk.html
52. nouveau.freedesktop.org news (NVK enabled for Maxwell, April 2025): https://nouveau.freedesktop.org/
53. chipStar repository: https://github.com/chip-spv/chipStar
54. Khronos blog on chipStar: https://www.khronos.org/blog/chipstar-brings-cuda-and-hip-applications-to-more-hardware-with-opencl-and-spir-v
55. chipStar discussion #833 (rusticl-nouveau double free, SPIR-V compile segfaults): https://github.imc.re/CHIP-SPV/chipStar/discussions/833
56. LLVM, "Compiling CUDA with clang": https://llvm.org/docs/CompileCudaWithLLVM.html

## 9. E0 results (2026-11-18, measured on the Nano)

Full table: results/cuda/E0-summary.md. Raw outputs beside it. Scripts: tools/cuda-e0/.

- E0a: 212 of 238 R32 ioctls match R36 by number, direction and struct size. 1 differs (IVM
  heaps). 25 are absent in R36, including CHANNEL_ALLOC_GPFIFO and several old NVMAP calls.
  Open: which of those the R32 libraries actually issue.
- E0b: R32 libraries need glibc 2.17 or newer, so they run on Arch. They also need
  /dev/nvhost-ctrl, /dev/nvhost-ctrl-gpu, /dev/nvmap and the tegra_fuse module parameters, which
  mainline lacks and a shim must supply.
- E0c: libnvrm_gpu.so in R35.6 and R36.4 still has the "NVIDIA Tegra X1 / GM20B" chip entry, the
  same as R32. R36.4 libcuda lists sm_53 among its JIT targets. That list may only describe the
  compiler, so it is weaker evidence than the chip entry. Verdict: advance the CUDA 12 route
  (R36 nvgpu plus R36 userspace) as a parallel experiment after E2.
- E0d: NVRTC 12.6 builds sm_53 PTX and cubin. The CUDA 10.2 cuobjdump reads the CUDA 12 cubin, and
  the CUDA 10.2 ptxas assembles CUDA 12 PTX once its .version is lowered to 6.5. nvcc 12.6 cannot
  parse the GCC 16 libstdc++ headers; NVRTC needs no host compiler.

## 10. Decision (2026-11-18, owner): CUDA 12 is the primary target

R36 userspace (CUDA 12.x) is built for the R36 nvgpu driver we are porting anyway, so the two
share one interface. That removes the E0a risk of the 25 missing ioctls. CUDA 12 also gives a
maintained toolchain, C++17/20 in device code, and current libraries and frameworks. It does not
make the GPU faster: GM20B hardware and its 25.6 GB/s memory bandwidth are the same.
CUDA 12.x is the last series that targets sm_53; CUDA 13 dropped it.

Order: E2 (R36 nvgpu on 7.2, shared by both routes) -> R36 userspace on GM20B (CUDA 12 deviceQuery)
-> if it fails, R32 userspace (CUDA 10.2) on the same driver as the control and fallback.

## 11. E2 result (2026-11-18, measured on the Nano)

E2 passed in one afternoon instead of the estimated 2-5 days.

- nvgpu.ko (OE4T linux-nvgpu patches-rel-36 + 1 commit) and nvmap.ko (OE4T linux-nv-oot
  patches-rel-36 + 4 commits) build against Linux 7.2.11 / GCC 16.1 with no errors and no modpost
  errors or warnings. Neither module depends on another module. Local forks:
  ~/projects/nvgpu-port/linux-nvgpu and linux-nv-oot, branch mainline-7.2. Build scripts:
  tools/cuda-e2/build-nvgpu.sh and build-nvmap.sh.
- Root cause of most early errors: NVIDIA's conftest probed without the kernel's C dialect, so with a
  C23-default compiler every probe failed (36 -> 82 probe results after the fix).
- Remaining downstream symbols were 2 (tegra_vpr_dev, emc_freq_to_bw), both handled by build
  options (VPR off; nv-oot mc-utils is Tegra234-only).
- Open items before CUDA work on nvmap: the kernel needs CONFIG_ARM64_PMEM=y (linux-nano), or
  nvmap's CPU cache invalidation is an empty stub. NvSciIpc is off (not needed for CUDA).
- E4 design: nvgpu binds the mainline "nvidia,gm20b" node (no DT change), powers the GPU with
  nouveau's mainline sequence (vdd regulator, gpu/ref/pwr clocks, gpu reset,
  tegra_pmc_powergate_remove_clamping), and does not autoload; desktop/AI mode switch = unbind
  nouveau, driver_override, bind. Firmware: R32.7.6 nvidia-l4t-firmware gm20b/ set (all nine
  files present except gpccs_sig.bin), installed under /usr/lib/firmware/gm20b/.

## 12. E4 result (2026-11-18, measured on the Nano): GM20B powers on under nvgpu

The R36 nvgpu driver brings the GPU up completely on mainline Linux 7.2.11 (nouveau not loaded).
The order observed: chip detect (gm20b rev a1), gcplex fuse "ACR non debug", ACR secure boot,
PMU, FECS/GPCCS ready, golden context built. All 14 /dev/nvgpu/igpu0/* nodes and the
/dev/nvhost-*-gpu set exist, runtime PM is `active`, and there are 0 SMMU faults and no oops.
Logs: results/cuda/e4-20261118-2035-power-on-ok-{netconsole,dmesg}.log.
Fork commits: 1e54a14 (identity IOMMU domain), f93672e (mainline power path).

Problems found and fixed on the way (each run is one cold boot):

| Symptom | Cause | Fix |
|---|---|---|
| ref clock lookup failed | downstream `gpu_ref` clock name | read the DT "ref" clock (clk.c) |
| fuse read failed | mainline has a gcplex NVMEM cell only for Tegra194 | `CONFIG_NVGPU_NVMEM_FUSE=n` (tegra_fuse_readl, same offsets) |
| PMU firmware -ENOENT | gm20b/ files are symlinks into tegra21x/ | install the real files |
| ACR firmware -ELOOP | firmware loader rejects symlinks | install the real files (`cp -L`) |
| FECS/GPCCS never boot, `gpusrd ... SMMU translation error` | mainline tegra-smmu gives the GPU an identity domain; nvgpu treated any domain as translating and set the SMMU aperture bit on physical addresses | `nvgpu_iommuable()` returns false for IOMMU_DOMAIN_IDENTITY |

Hardware rules learned: a GPU fault needs a cold power cycle (a warm reboot leaves the chip
reading 00000000); never rmmod nvgpu after a failed power-on (the remove path touches the GPU and
raised an SError); mainline nouveau unbind on GM20B oopses (nvkm_mmu_dtor, devfreq teardown), so
the live desktop/AI switch needs a nouveau fix first.

Next: kernel with CONFIG_ARM64_PMEM=y (nvmap cache maintenance), then the R36 userspace and a
CUDA 12 deviceQuery.

## 13. E5 result (2026-11-19, measured on the Nano): CUDA 12.6 runs on GM20B

First CUDA work on this GPU through the R36 stack on mainline Linux, kernel `linux-nano`
7.2.11-1 (packaging/linux-nano: ALARM config + `CONFIG_ARM64_PMEM`), nvgpu and nvmap from the
forks, L4T R36.4.7 userspace (libcuda driver API 12060 = CUDA 12.6), NVRTC 12.6.

```
device: NVIDIA Tegra X1, compute 5.3, 1 SM, 3874 MiB, driver API 12060
sm_53 cubin: 0 wrong of 1048576, kernel 1.370 ms, 9.18 GB/s
compute_53 PTX (driver JIT): 0 wrong of 1048576, kernel 1.372 ms, 9.17 GB/s
E5 PASS
```

Test: tools/cuda-e5/cuda_smoke.c (driver API only; `y = 2a + b` over 1 Mi floats, every element
checked on the CPU). Logs: results/cuda/e5-20261119-*.log.

What it took after E4:

| Symptom | Cause | Fix |
|---|---|---|
| no /dev/nvmap | nvmap binds only to an `nvidia,carveouts` DT node | images/mainline-kernel/b01/nvmap-carveouts.dtsi, built into a separate `-nano.dtb` by make-nano-dtb.sh |
| kernel oops at pc 0x0 on cuInit | gm20b has no clk_arb range op; without Tegra DVFS nvgpu called it anyway | fork commit 7db245e: unset clk_arb ops return an error |
| CUDA_ERROR_JIT_COMPILER_NOT_FOUND for PTX | libnvidia-ptxjitcompiler ships in nvidia-l4t-3d-core | add that package's libraries |

Open items:
- Clocks: with no DVFS, nvgpu neither scales the GPU voltage nor raises GPCPLL, so the GPU stays at
  its boot clock (the 998 MHz CUDA reports is the chip-table value, not the running clock). The
  9.2 GB/s above is 36% of the 25.6 GB/s peak. Next: mainline-style voltage/frequency scaling (CVB
  tables from the speedo fuses, as nouveau does) so the GPU can run at its rated clock.
- `/dev/host1x-fence` is missing (nv-oot host1x-fence); libcuda logs it and continues. Needed for
  sync-fd interop with other engines, not for compute.
- Packaging: nvgpu/nvmap module package, GM20B firmware, R36 userspace (core, cuda, 3d-core) with
  a linker config instead of LD_LIBRARY_PATH, udev rules for the device nodes.

## 14. G1 first attempt (2026-11-19, measured): NVIDIA R36 Vulkan on nvgpu

`vulkaninfo` with only the R36 ICD (`libGLX_nvidia.so.0`, Vulkan 1.3.251, from nvidia-l4t-3d-core
36.4.7) and nvgpu + nvmap loaded: the loader opens the ICD, but `vk_icdGetInstanceProcAddr` returns
no `vkCreateInstance` (VK_ERROR_INCOMPATIBLE_DRIVER). strace: the driver stats `/dev/dri/card0`
and `renderD128` (both mainline tegra-drm) and stops; it never opens an nvgpu, nvmap or nvhost node.
No library is missing (only the optional application-profile files).

Reading (inferred): R36 graphics on Orin expects NVIDIA's own display stack (nvidia-drm on
nvdisplay); with only mainline tegra-drm present, it finds no device it accepts. Options to test:
1. what device check the ICD makes (ltrace/gdb on the DRM probe), and whether a render-only
   path exists that accepts a non-NVIDIA DRM node or none at all;
2. R32.7.6 graphics libraries (built for T210 with nvgpu + tegra-udrm) on the R36 nvgpu, using
   the E0a ioctl map (212 of 238 ioctls identical);
3. fallback for desktop + CUDA together: keep CUDA on nvgpu and look at a shared-GPU design only
   if 1 and 2 fail.

## 15. G1 result (2026-11-19, measured): NVIDIA Vulkan 1.3 runs on GM20B through nvgpu

The §14 failure had a simple cause: the R36 Vulkan ICD (`libGLX_nvidia.so.0`) initialises through
NVIDIA's EGL, and glvnd only had Mesa's EGL vendor registered. With NVIDIA's `tegra-egl/nvidia.json`
registered (`__EGL_VENDOR_LIBRARY_FILENAMES`, test only), in the CUDA boot mode:

```
device: NVIDIA Tegra X1 (nvgpu), Vulkan 1.3.251, vendor 0x10de
queue family 0: flags 0xf (graphics, compute, transfer, sparse), 16 queues
compute shader: 0 wrong of 1048576
G1 PASS
```

Test: tools/cuda-e5/vk_probe.c (+ vk_probe.comp), no window system. Logs:
results/cuda/g1-20261119-*.log. `vulkaninfo` itself stops at VK_KHR_display, which wants the
downstream display device `/dev/tegra_dc_ctrl` (nvdc); the desktop does not need that path.

Extensions that matter for a compositor on this stack: VK_EXT_external_memory_dma_buf,
VK_EXT_image_drm_format_modifier, VK_KHR_external_memory_fd, VK_KHR_external_semaphore_fd,
VK_KHR_external_fence_fd, VK_KHR_timeline_semaphore, VK_EXT_physical_device_drm, VK_KHR_swapchain
(155 device extensions in all).

Next (G2): Mesa with the Zink driver on this ICD, headless GL first, then GBM on the tegra-drm
card, then Hyprland. Open question: how Zink matches the tegra-drm card to a Vulkan device whose
DRM node identity (VK_EXT_physical_device_drm) is not a tegra-drm node.

## 16. G2 result (2026-11-19, measured): OpenGL 4.6 through Zink on NVIDIA Vulkan over nvgpu

Mesa 26.2.5 (packaging/mesa-tegra, release 1.6) with Zink, on NVIDIA's R36 Vulkan driver, on
nvgpu, in the CUDA boot mode (the same driver stack CUDA uses):

```
OpenGL core profile renderer: zink Vulkan 1.3(NVIDIA Tegra X1 (nvgpu) (NVIDIA_PROPRIETARY))
OpenGL core profile version: 4.6 (Core Profile) Mesa 26.2.5
OpenGL ES profile version: OpenGL ES 3.1 Mesa 26.2.5
gbmclear /dev/dri/card0 and renderD128 (GBM + EGL + GLES clear + readback): pixel 0 255 0 255 (expected)
```

Three Zink blockers, each fixed by a Mesa patch in packaging/mesa-tegra:

| Blocker | Cause | Patch |
|---|---|---|
| `failed to choose pdev` | the only DRM device is tegra-drm (display); NVIDIA's Vulkan device has no DRM node (nvgpu is not DRM) | 0002: pair a display-only DRM device with the only Vulkan device that has no DRM node |
| silent failure in feature detection | Zink 26 requires VK_KHR_maintenance5; NVIDIA R36 (540, Vulkan 1.3.251) predates it | 0003: maintenance5 optional; keep PointSize stores and skip VkBufferUsageFlags2CreateInfo without it |
| `vkCreateDevice` VK_ERROR_DEVICE_LOST | Zink adds a queue on the sparse-only family 1, a host1x engine queue that issues downstream nvhost ioctls ('H') on the mainline tegra-drm node (ENOTTY) | 0004: retry with the graphics family (which supports sparse binding) when the extra queue fails |

Test setup (not yet packaged): VK_DRIVER_FILES = R36 ICD, __EGL_VENDOR_LIBRARY_FILENAMES = Mesa
then NVIDIA (NVIDIA's Vulkan initialises through its own EGL), MESA_LOADER_DRIVER_OVERRIDE=zink,
LD_LIBRARY_PATH = unpacked R36 core, cuda and 3d-core. Log: results/cuda/g2-20261119-0200-*.log.

Known issue: a GL process can crash at exit (SIGSEGV in a libnvidia-eglcore worker thread after
teardown starts; seen once on card0, rendering result already correct). Must be fixed before the
desktop uses this stack.

Next: Hyprland (Omarchy) on this stack, scanout through tegra-drm.

## 17. G2 desktop attempts (2026-11-19, measured): Hyprland on Zink/nvgpu, scanout blocked, then a crash

Run 1 (01:53, CUDA boot mode, test environment for SDDM and the session): Hyprland starts and
renders through Zink on NVIDIA Vulkan, but the monitor stays at mode 0x0. aquamarine:
`GBM: Failed to query fd for plane 0`, `Buffer failed to import to KMS`. Probes
(results/cuda/g2-20261119-0205-scanout-probes.log):
- NVIDIA Vulkan can export dma-buf for B8G8R8A8/R8G8B8A8 (optimal and linear).
- Its DRM modifiers are LINEAR and NVIDIA block-linear with page kind 0xfe
  (0x03000000000fe010-15); LINEAR is not a colour attachment (features 0x1d403), so Zink cannot
  render to it.
- tegra-drm advertises LINEAR and block-linear with page kind 0 only. drm_fourcc.h defines kind 0
  as the legacy spelling of kind 0xfe, but tegra-drm does not canonicalise, so the only common
  modifier is LINEAR, which the GPU cannot render to.

Run 2 (02:09): tegra-drm patched to accept and advertise the canonical form
(packaging/linux-nano/pending/0102-*.patch, out-of-tree module). 4 s after the desktop started:
`kernel BUG at include/linux/page-flags.h:992`, a free page with corrupted state (still
mapped, mlocked), then a hang. Run 1 had no import path and ran ~10 min without a fault, so the
leading suspect is the nvmap dma-buf export to tegra-drm import (our nvmap port changed the
dma-buf ops: cache_sgt_mapping removed, file refcount API). Unproven.

The desktop test is runtime-only and off: tools/cuda-e5/g2-desktop-env.sh writes /run files only
when DESKTOP_ENV is set for the CUDA boot mode. Next: a debug kernel (DEBUG_PAGEALLOC, KASAN,
DMA-API debug) to find the faulting free; then nvmap's dma-buf map/unmap against 7.2 semantics.

## 18. G2 desktop result (2026-11-20, measured): Hyprland on Zink/nvgpu without corruption

The Omarchy desktop (Hyprland, quickshell bar and wallpaper, Xwayland) runs on Zink on NVIDIA's
R36 Vulkan driver over nvgpu, with scanout through tegra-drm (0102 patch, out-of-tree module), in
the CUDA boot mode. CUDA 12.6 (E5) and Vulkan compute (G1) still pass in the same boot.

Fixes since section 17:

| Symptom | Cause | Fix |
|---|---|---|
| client windows black on the compositor | NVIDIA's driver allocates new zeroed memory when an import and VkExportMemoryAllocateInfo share one vkAllocateMemory | mesa-tegra 0005 (release 1.7): no export structure on dma-buf imports with NVIDIA |
| Xwayland hangs, every client blocks behind it | libGLX_nvidia calls XOpenDisplay() while it loads as the Vulkan ICD, inside the X server | ICD library is libEGL_nvidia (same ICD entry points), tools/cuda-e5/g2-desktop-env.sh |
| deadlock in eglMakeCurrent (pthread_cond_destroy in libnvidia-eglcore) | NVIDIA's Vulkan WSI under Zink's kopper | LIBGL_KOPPER_DISABLE=true: present through dma-buf |
| truncated NVIDIA libraries after a crash | the copy was skipped when it already existed | copy into a new folder, verify each file, sync, swap |
| GPU submit fails on a foreign sync_file | nvgpu accepted only its own fences | linux-nvgpu: CPU wait on foreign fences, then a signalled stub |
| garbage blocks: alternating 128-pixel column bands in block-linear surfaces, worse as memory fragments | see below | linux-nvgpu small-PTE fix and linux-nv-oot nvmap cache fix |

Garbage blocks, two root causes:
1. nvmap built with NVMAP_UPSTREAM_KERNEL used arch_invalidate_pmem() for write-back-and-
   invalidate and after zeroing carveouts. On arm64 mainline that only invalidates, so dirty CPU
   lines were discarded. Fix: the module's own __dma_flush_area() (dc civac) in every case; the
   CONFIG_ARCH_HAS_PMEM_API build requirement goes away with it.
2. The main cause. Mainline tegra-smmu gives the GPU an identity domain, so GPU addresses are
   physical. GM20B big pages are 128 KiB, nvmap allocates in 64 KiB runs. nvgpu already used
   small pages for normal maps without an SMMU, but fixed-address maps into a vm_area (the NVIDIA
   user-mode driver's path), split-VA, sparse and remap maps still used big PTEs. A big PTE over
   two separate runs maps half of the big page to the wrong memory: one 128-pixel column band of a
   1280-wide ARGB block-linear surface is 64 KiB. Fix: nvgpu_vm_pte_pgsz() gives small PTEs for
   every map when nvgpu_iommuable() is false; VA reservations keep their page size.

Cross-process check (render 1280x720 block-linear in one process, import the dma-buf in another,
compare every pixel; tools/cuda-e5/g2-xproc.c, run N times by g2-xstress.sh):

| nvgpu build | runs with wrong pixels |
|---|---|
| before the small-PTE fix (nvmap cache fix in) | 3 of 10 |
| with the small-PTE fix, fresh boot | 0 of 20 |
| with the small-PTE fix, after 3 session restarts and 5 quickshell restarts (no free 2 MiB blocks left) | 0 of 20 |

Screenshots after each restart show no corrupt bands. The section 17 page-state BUG did not
come back in this boot (20 min, many desktop restarts); its cause is not confirmed.

Still open: hardware cursor (the cursor plane takes linear buffers only), GPU DVFS (the GPU runs
at its boot clock), the GL exit crash in libnvidia-eglcore, /dev/host1x-fence, and packaging
(R36 userspace package, udev rules, firmware, 0102 into linux-nano, removal of the test autorun).
Later: a translating SMMU domain for the GPU (GPU_IOMMU=DMA in the autorun) would allow big pages
again.

## 19. GPU DVFS and memory clock (2026-11-20, measured)

- DVFS on mainline (linux-nvgpu `b2e0641`): GM20B frequency/voltage points from NVIDIA's Tegra210
  CVB coefficients (PLL mode) and the GPU speedo; this board, speedo 1986 (ID 2): 76.8 to 921.6
  MHz at 818 to 1178 mV; devfreq simple_ondemand with nouveau's thresholds (up at 45% load). Before,
  the GPU sat at the 217.6 MHz boot clock with the rail at 710 mV.
- tools/cuda-e5/gpu_load.c (FMA kernel, results checked against the CPU): ramps 537.6 -> 921.6 MHz
  within a second, 188 GFLOP/s (about 44 at the old clock); 5-minute soak at 921.6 MHz, 25686
  launches, all checked results correct, peak 50.5 C, no GPU errors.
- Memory clock: the guarded EMC raise (local service, to be packaged) left its marker after a hung
  boot at 01:16, so every later boot stayed at 204 MHz and the desktop felt sluggish. Marker
  cleared; EMC at 1600 MHz again.
- /dev/host1x-fence: not needed. NVIDIA's R36 host1x-fence driver matches Tegra186/194/234 only,
  and nvgpu on GM20B uses semaphores, not host1x syncpoints; the R36 libraries only log that the
  node is missing.
- Hyprland exit crash: aquamarine's `backendInUse` (src/backend/Session.cpp, used only to route
  libseat/libinput logs) held a strong reference nothing released, so the backend outlived
  Hyprland's cleanup and was destroyed by libaquamarine's static destructors, after
  libEGL_nvidia's destructor had unloaded libnvidia-eglcore; freeing the GBM buffers then jumped
  into unloaded code. Upstream main still has it. Fixed in `packaging/aquamarine-nano` (Omarchy's
  0.15.1-1.3 plus 0005: a weak reference). Measured: patched Hyprland exits with no core dump
  (the unpatched one dumped core on every exit).
- Hardware cursor: blocked in tegra-drm, not in Hyprland. On Tegra20 to Tegra210 the cursor plane
  advertises only DRM_FORMAT_RGBA8888 (`tegra_legacy_cursor_plane_formats`; Tegra186+ takes
  ARGB8888). Cursors are ARGB8888 everywhere (Hyprland's CPU-buffer path, modetest -C, X), and
  the atomic check rejects them (`__setplane_check: Invalid pixel format AR24, modifier 0x0`, with
  DRM debug on). Hyprland's GBM path picks RA24 but needs a LINEAR buffer, which NVIDIA's Vulkan
  driver cannot render to. So any compositor falls back to a software cursor on this display.
  Fixed in `packaging/hyprland-nano` (Omarchy's 0.56.2-7 plus 0001): with
  `cursor:use_cpu_buffer = 1`, the CPU cursor path allocates RGBA8888 when the plane has no
  ARGB8888 and moves alpha to the low byte while copying. Measured: the cursor plane carries a
  framebuffer (crtc-0) and aquamarine allocates RA24 dumb buffers.

## 20. Packaging (2026-11-20)

The test setup (`/root/e4-autorun.enabled`, the `/opt/nvidia-l4t-r36-test` copy, runtime
environment files, world-writable device nodes, firmware from a home directory) is replaced by
packages in `packaging/`. NVIDIA files are downloaded from repo.download.nvidia.com at build time,
pinned by SHA-256, and never stored in this repository.

| Package | Contents | State |
|---|---|---|
| `nvidia-l4t-gm20b-firmware` 32.7.6 | GM20B nvgpu firmware from L4T R32.7.6 `nvidia-l4t-firmware`, symlinks resolved (the loader rejects them) | installed; byte-identical to the tested set |
| `nvidia-l4t-r36` 36.4.7 | R36.4 core, cuda and 3d-core libraries in `/usr/lib/nvidia-l4t` (ld.so.conf.d; no name clashes with system libraries); Vulkan ICD manifest outside the loader's default directory | installed; all 62 libraries identical to the tested copy; CUDA, Vulkan compute and the Zink pixel check pass on it without `LD_LIBRARY_PATH` |
| `nvgpu-nano` | nvgpu + nvmap built from the pinned fork commits; `softdep nvgpu pre: nvmap`; udev rules (video group 0660 + uaccess; debug, profiler and scheduler nodes group only); system and user environment generators that set Zink, `VK_DRIVER_FILES` and `LIBGL_KOPPER_DISABLE` in the CUDA boot mode only | built for 7.2.11-2 and installed; loads by the device-tree alias at boot |
| `jetson-nano-board` | udev rules: GPU devfreq floor 537.6 MHz and fan start 38 C applied when the devices appear (boot services raced the drivers); guarded EMC raise that skips one boot after a hang instead of staying at 204 MHz for good | installed; rules verified with synthetic add events |
| `linux-nano` 7.2.11-2 | 0102 tegra-drm canonical modifiers applied; `CONFIG_ARM64_PMEM` dropped (nvmap no longer needs it) | built with distcc on an x86 cross compiler (GCC 16.2 vs 16.1 native, no plugins), installed, booting |

The NVIDIA EGL vendor file is no longer registered: Zink on NVIDIA's Vulkan driver works without
it (tested), and glvnd then never routes EGL clients to NVIDIA's EGL, which has no display path on
mainline.

Switch-over (needs someone at the board, a warm reboot can hang):
1. Install `linux-nano` and `linux-nano-headers` 7.2.11-2; rebuild `nvgpu-nano` with
   `_kernver=7.2.11-2-nano-ARCH` and install it.
2. Boot entries: the nouveau entry gets `modprobe.blacklist=nvgpu` (both drivers match the GPU);
   the CUDA entry keeps `modprobe.blacklist=nouveau nano.mode=cuda`.
3. Remove the test pieces: `/root/e4-autorun.enabled`, `/opt/nvidia-l4t-r36-test`, `/opt/g2-test`
   and `/etc/modprobe.d/g2-tegra-drm.conf`.
4. Reboot into the CUDA entry; check CUDA, Vulkan, the pixel check, devfreq and the desktop as a
   normal user (no `chmod`).

### Switch-over result (2026-11-20, measured)

Done as listed above, plus: the four local `jetson-*` units disabled (the board package replaces
them), and the old `/opt/mesa-*` debug trees and `tegra-drm-select.sh` moved to a backup folder.
The warm reboot hung again (log ends at `Rebooting.`, nvgpu PMU wait timeout); a power cycle
booted the new entry. On that boot, with nothing but the packages:

| Check | Result |
|---|---|
| kernel, mode | 7.2.11-2-nano-ARCH, `nano.mode=cuda` |
| modules | nvmap, nvgpu, tegra_drm load on their own (softdep + alias) |
| DVFS | `GPU speedo 1986 (ID 2), 76-921 MHz at 818-1178 mV`; `simple_ondemand`, floor 537.6 MHz |
| EMC | 1600 MHz (`jetson-nano-emc` active) |
| fan | active trip 38 C |
| device nodes | `root:video 0660` plus a seat ACL for the desktop user |
| session environment | Hyprland has `MESA_LOADER_DRIVER_OVERRIDE=zink`, `VK_DRIVER_FILES`, `LIBGL_KOPPER_DISABLE` from the generator |
| hardware cursor | cursor plane on `crtc-0`, format RA24 |
| failed units | none |
| pixel check (`g2-xstress.sh 20`, environment from the generator) | 0 of 20 runs with wrong pixels |
| Vulkan (`vk_probe`, user omarchy) | compute shader 0 wrong of 1048576, G1 PASS |
| CUDA (`cuda_smoke`, user omarchy) | PTX JIT 0 wrong of 1048576, E5 PASS |
| CUDA load (`gpu_load`, user omarchy) | 921.6 MHz under load, 188 GFLOP/s, 0 wrong of 1298 checked; back to 537.6 MHz idle |

Found during the checks:
- **pwm-tegra DKMS replaced linux-nano's own module.** DKMS archived the packaged
  `kernel/drivers/pwm/pwm-tegra.ko` and installed its copy under `updates/` (`pacman -Qkk` reported
  the file missing). The DKMS module exists only for the stock ALARM kernel, which lacks the
  driver; its `dkms.conf` now has `BUILD_EXCLUSIVE_KERNEL="-aarch64-ARCH$"`, and removing it from
  7.2.11-2 restored the packaged file. The in-tree module is used from the next boot.
- **Headless CUDA needs group `video`.** The seat ACL covers only the logged-in desktop user;
  provisioning now adds the user to `video` for CUDA over ssh or from services.
- **The CUDA toolkit is not packaged.** `nvidia-l4t-r36` is the driver (`libcuda`, Vulkan, EGL);
  programs that compile at run time also need NVRTC (`libnvrtc.so.12`) from the CUDA 12.6
  toolkit, still used from the unpacked archive. A toolkit package is the next packaging step.
- **`vulkaninfo` still aborts** (`free(): invalid pointer` in `libnvidia-eglcore` during
  `vkEnumeratePhysicalDevices`, right after `libnvdc` fails to open the downstream
  `/dev/tegra_dc_ctrl`), as in §15. A minimal program that enables all 21 instance extensions
  and calls the `VK_KHR_display` queries gets `VK_ERROR_INITIALIZATION_FAILED` without a crash,
  so the trigger is a vulkaninfo call sequence not yet isolated. Zink and the probes do not hit it.
