# CrossSim (gem5 ↔ Questa RTL)

Co-simulation bridge: **gem5** issues memory traffic; **Questa** runs the HBM controller RTL. A DPI-C shared library (`crosssim.so`) and POSIX shared-memory queues connect the two processes.

## Contents of this directory

| Path | Purpose |
| ---- | ------- |
| [`gem5/`](gem5/) | `DpiMemCtrl` SimObject sources and example [`simple.py`](gem5/simple.py) |
| [`crosssim/`](crosssim/) | C sources and Makefile for `crosssim.so` |
| [`HBM_controller_crosssim_dpi_tb_template.sv`](HBM_controller_crosssim_dpi_tb_template.sv) | SystemVerilog starting point: DPI imports + `HBM_controller_top` instance |
| [`CrossSim.pdf`](CrossSim.pdf) | Optional longer write-up (same material as the PNG figure, PDF format) |

Block diagram (kept under `doc/` with the other figures): [`../doc/CrossSim.png`](../doc/CrossSim.png). Short pointer in the main project readme: [`../README.md`](../README.md) → **Simulation flow**.

Some external CrossSim trees ship Vivado-oriented example HDL; **this** repo documents a Questa + DPI path using the template above.

---

## DPI entry points

Declared in [`crosssim/inc/crosssim.h`](crosssim/inc/crosssim.h):

- `initialize`, `finalize`
- `gem5_send`, `gem5_receive`
- `gem5_functional_send`, `gem5_functional_receive`
- `questa_send`, `questa_receive` and `questa_functional_*`

---

## Prerequisites

- Linux (tested workflow).
- gem5 source tree + build dependencies.
- QuestaSim (or another simulator with compatible DPI-C for your flow).
- Vivado, if you need `compile_simlib` for Xilinx HBM/PHY models in elaboration.
- C compiler compatible with Questa for building `crosssim.so`.

**References:** [gem5 SimObjects](https://www.gem5.org/documentation/learning_gem5/part2/helloobject/), [Vivado compile_simlib](https://docs.amd.com/r/en-US/ug900-vivado-logic-simulation/Compiling-Simulation-Libraries), [PG276 simulation](https://docs.amd.com/r/en-US/pg276-axi-hbm/Simulation).

---

## Recommended build order

1. Integrate `DpiMemCtrl` into gem5 and build gem5 (below).
2. Run Vivado `compile_simlib` for Questa if Xilinx IP models are required.
3. Build `crosssim.so` in `crosssim/`.
4. Set an **absolute** path to `crosssim.so` in `gem5/simple.py`.
5. Start gem5 and Questa **together**; RTL TB loads the same `.so` and calls `initialize` / `questa_*`.

---

### 1) gem5: copy `DpiMemCtrl` and build

From the **HBMController repository root**:

```bash
mkdir -p /path/to/gem5/src/learning_gem5/my_mem_ctrl
cp CrossSim/gem5/DpiMemCtrl.cc  /path/to/gem5/src/learning_gem5/my_mem_ctrl/
cp CrossSim/gem5/DpiMemCtrl.hh  /path/to/gem5/src/learning_gem5/my_mem_ctrl/
cp CrossSim/gem5/DpiMemCtrl.py  /path/to/gem5/src/learning_gem5/my_mem_ctrl/
cp CrossSim/gem5/SConscript      /path/to/gem5/src/learning_gem5/my_mem_ctrl/
```

Build (example ISA):

```bash
cd /path/to/gem5
scons build/X86/gem5.opt -j"$(nproc)"
```

Rebuild after any change to those sources.

---

### 2) Vivado simulation libraries (Questa)

```tcl
compile_simlib -language all \
               -simulator questa \
               -simulator_exec_path {/path/to/questasim/bin} \
               -dir {/path/to/vivado_questa_libs}
```

Point Questa at the generated `modelsim.ini` / libraries when compiling the full HBM testbench.

---

### 3) Build `crosssim.so`

```bash
cd CrossSim/crosssim
make clean
make CC=/path/to/questasim/gcc-*/bin/gcc
```

Output: `CrossSim/crosssim/bin/crosssim.so` (default `CC` is `gcc` if you override in the Makefile).

---

### 4) gem5 config: `shared_lib_path`

Edit [`gem5/simple.py`](gem5/simple.py): `DpiMemCtrl(shared_lib_path="...")` must be an absolute path to `crosssim.so`.

---

### 5) RTL testbench

Start from [`HBM_controller_crosssim_dpi_tb_template.sv`](HBM_controller_crosssim_dpi_tb_template.sv). It already imports the DPI routines, calls `initialize` / `finalize`, and instantiates `HBM_controller_top`. You still need logic that:

- calls `questa_receive` and maps fields to `address`, `request`, `write_data`, `request_valid`, `request_id`;
- on completion, calls `questa_send` (or functional variants) per `crosssim.c` queue semantics.

Match the compiler/ABI used for `crosssim.so` when elaborating with Questa.

---

## Sanity checklist

- [ ] gem5 builds with `DpiMemCtrl` under `src/learning_gem5/my_mem_ctrl`.
- [ ] `crosssim.so` exists; `ldd` is clean for your environment.
- [ ] `shared_lib_path` in Python points at that file.
- [ ] Questa loads the same `.so` with DPI enabled.
- [ ] Both processes run concurrently so `shm_open` regions in `crosssim.c` are active.

## Troubleshooting

| Symptom | Things to check |
| ------- | ---------------- |
| gem5 cannot load `.so` | Absolute path, permissions, `ldd crosssim.so`. |
| DPI symbol missing | SV `import "DPI-C"` signatures vs `crosssim.h`. |
| Unresolved Xilinx cells | Re-run `compile_simlib` for your Vivado/Questa pair. |
| Empty queues | Both sides called `initialize()`; both still running; `/dev/shm` permissions. |

---

## Related layout (public reference)

Directory naming follows the [HiSA-Team/CrossSim](https://github.com/HiSA-Team/CrossSim) style (`gem5` + `crosssim` side by side).
