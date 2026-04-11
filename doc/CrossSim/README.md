# CrossSim co-simulation (gem5 ↔ Questa RTL)

This guide is adapted from the public [CrossSim](https://github.com/HiSA-Team/CrossSim) reference tree. In **this** repository, the **gem5** integration sources and the **CrossSim DPI shared library** sources live under [`CrossSim/`](../../CrossSim/README.md). The upstream **Vivado** example testbenches are **not** included here; instead, use the DPI template next to this file and wire it to your Questa flow and Xilinx simulation models.

## Architecture at a glance

- [`CrossSim/gem5/`](../../CrossSim/gem5/) — custom gem5 memory controller (`DpiMemCtrl`) and example run script `simple.py`.
- [`CrossSim/crosssim/`](../../CrossSim/crosssim/) — builds the DPI shared library `crosssim.so` used by gem5 and the HDL simulator.

Main DPI symbols are declared in [`CrossSim/crosssim/inc/crosssim.h`](../../CrossSim/crosssim/inc/crosssim.h):

- `initialize`, `finalize`
- `gem5_send`, `gem5_receive`
- `gem5_functional_send`, `gem5_functional_receive`
- `questa_send`, `questa_receive` and functional counterparts (`questa_functional_*`)

## Prerequisites

### Required tools

- Linux environment (CrossSim is exercised on Linux).
- A gem5 source tree and gem5 build dependencies.
- QuestaSim (or another simulator that supports DPI-C with your flow).
- Vivado (to compile Xilinx simulation libraries for Questa when the RTL instantiates Xilinx IP such as HBM PHY models).
- A C compiler compatible with your Questa/DPI setup for building `crosssim.so`.

### Useful references

- gem5 Learning gem5 (SimObjects): [Hello object](https://www.gem5.org/documentation/learning_gem5/part2/helloobject/), [memory objects](https://www.gem5.org/documentation/learning_gem5/part2/memoryobject/)
- Vivado logic simulation UG900 — [compiling simulation libraries](https://docs.amd.com/r/en-US/ug900-vivado-logic-simulation/Compiling-Simulation-Libraries)
- AXI HBM PG276 — [simulation chapter](https://docs.amd.com/r/en-US/pg276-axi-hbm/Simulation)

## Build flow (recommended order)

1. Integrate and build gem5 with `DpiMemCtrl` (paths below).
2. Compile Vivado simulation libraries for Questa if your RTL includes Xilinx IP.
3. Build `crosssim.so` from `CrossSim/crosssim`.
4. Point gem5 (`simple.py`) at the absolute path of `crosssim.so`.
5. Run gem5 and Questa **concurrently**; the RTL testbench must `import "DPI-C"` the same library and call `initialize` / `questa_*` as described in the template.

---

## 1) Integrate `DpiMemCtrl` in gem5 and build gem5

Copy these files into your gem5 tree (from the repository root):

```bash
mkdir -p /path/to/gem5/src/learning_gem5/my_mem_ctrl
cp CrossSim/gem5/DpiMemCtrl.cc /path/to/gem5/src/learning_gem5/my_mem_ctrl/
cp CrossSim/gem5/DpiMemCtrl.hh /path/to/gem5/src/learning_gem5/my_mem_ctrl/
cp CrossSim/gem5/DpiMemCtrl.py /path/to/gem5/src/learning_gem5/my_mem_ctrl/
cp CrossSim/gem5/SConscript   /path/to/gem5/src/learning_gem5/my_mem_ctrl/
```

`DpiMemCtrl.py` expects the header at `learning_gem5/my_mem_ctrl/DpiMemCtrl.hh` (as above).

Build gem5 (example for X86):

```bash
cd /path/to/gem5
scons build/X86/gem5.opt -j"$(nproc)"
```

Re-run `scons` whenever `DpiMemCtrl` sources change.

---

## 2) Compile Vivado simulation libraries for Questa

If the RTL testbench uses Xilinx-generated models/IPs, compile Vivado libraries for Questa once per Vivado/Questa version pair.

From the Vivado Tcl console:

```tcl
compile_simlib -language all \
               -simulator questa \
               -simulator_exec_path {/path/to/questasim/bin} \
               -dir {/path/to/vivado_questa_libs}
```

Use the generated `modelsim.ini` / library mappings when compiling and elaborating the HBM controller + PHY testbench.

---

## 3) Build the CrossSim DPI shared library

The Makefile lives in [`CrossSim/crosssim/Makefile`](../../CrossSim/crosssim/Makefile). By default `CC` is `gcc`; for Questa DPI you often need the GCC bundled with Questa:

```bash
cd CrossSim/crosssim
make clean
make CC=/path/to/questasim/gcc-*/bin/gcc
```

Artifact:

- `CrossSim/crosssim/bin/crosssim.so`

---

## 4) Point gem5 to `crosssim.so`

Edit [`CrossSim/gem5/simple.py`](../../CrossSim/gem5/simple.py) and set `DpiMemCtrl(shared_lib_path=...)` to an **absolute** path to `crosssim.so`.

---

## 5) RTL side: DPI testbench for this controller

The public CrossSim tree ships example SystemVerilog under `sources/vivado/`; **this** repository does not include those files.

For this HBM controller, start from:

- [`HBM_controller_crosssim_dpi_tb_template.sv`](HBM_controller_crosssim_dpi_tb_template.sv)

That template declares the DPI imports, calls `initialize()`, and instantiates `HBM_controller_top` with the same class of ports as the trace-based testbench. You must extend it with a timing-accurate loop that:

- pulls memory transactions from gem5 via `questa_receive`, maps them onto `address` / `request` / `write_data` / `request_valid` / `request_id`, and
- pushes completions back toward gem5 via `questa_send` (and/or the functional variants), consistent with the queue semantics in `crosssim.c`.

Run Questa with DPI loading `crosssim.so` (exact `vsim`/`vopt` flags depend on your site; match the compiler ABI used to build the `.so`).

---

## Minimal sanity checklist

- gem5 builds with `DpiMemCtrl` under `src/learning_gem5/my_mem_ctrl`.
- `crosssim.so` exists and exports the symbols from `crosssim.h`.
- `shared_lib_path` in the gem5 script points to that `.so`.
- Vivado simulation libraries are compiled for Questa if Xilinx IP models are in the elaboration.
- Questa elaborates the testbench with DPI enabled and loads the same `crosssim.so` as gem5.
- gem5 and Questa run **at the same time** so shared-memory queues (`/dev/shm`, `shm_open` names in `crosssim.c`) are live.

## Troubleshooting

- **`Failed to load shared library` in gem5** — Check absolute path, permissions, and dependencies (`ldd /path/to/crosssim.so`).
- **DPI symbol not found** — Ensure `import "DPI-C"` function names and signatures match `crosssim.h` and the compiled object.
- **Questa/Vivado model library errors** — Re-run `compile_simlib` for your tool versions; use the correct `modelsim.ini`.
- **No queue traffic** — Both sides must call `initialize()`; both processes must be running; check shared-memory permissions.

## Upstream license

See [`CrossSim/LICENSE.CrossSim-upstream`](../../CrossSim/LICENSE.CrossSim-upstream) for the license file carried with these sources.
