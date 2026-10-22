# Parameterized Matrix Multiplier Accelerator with UVM Verification

Final-year B.Tech project, Dept. of Electronics & Telecommunication Engineering, Symbiosis Institute of Technology, Pune (2023-27).
**Group 8:** Saaj Mulik, Shloka Patel, Shrey Raj, Swayam Patel. **Guide:** Dr. Suman Lata Tripathi.

An output-stationary systolic-array matrix multiplier in SystemVerilog, parameterized by array size `N` and operand width `W`,
verified with a UVM testbench (Python/NumPy golden model, constrained-random stimulus, functional coverage, SVA) and demonstrated on a
PINE S7 (Spartan-7 XC7S15) FPGA board as a 4-class neural-network layer.

## Key results
| | N = 2 | N = 4 | N = 8 |
|---|---|---|---|
| Regression (168 Python vectors + 200 random) | 368 PASS / 0 FAIL | 368 PASS / 0 FAIL | 368 PASS / 0 FAIL |
| Functional coverage (47 bins) | 100 % | 100 % | 100 % |
| Assertions (6 SVA) | all held | all held | all held |
| Latency | 5 clocks | 11 clocks | 23 clocks (3N-1) |

FPGA (N = 4, W = 8, 100 MHz, Vivado 2019.1): 1054 LUTs (13.18 %), 402 registers, 0 DSP, WNS +0.252 ns, WHS +0.054 ns, all constraints met.
UVM, SVA and coverage were run on Cadence Incisive (irun 15.20) in the college lab.

## Repository layout
| Folder | Contents |
|---|---|
| `rtl/` | `pe.sv` (processing element), `systolic_matmul.sv` (parameterized array + controller), `matmul_flat.sv` (1-cycle baseline) |
| `ncsim/` | Self-contained simulation folder: UVM package, interface, top testbench, SVA, vector files, `run.sh` |
| `python/` | `golden_model.py` (vector generation, coverage prediction), `ai_demo.py` (weights/samples for the FPGA demo) |
| `fpga/` | `fpga_top.sv`, `pine_s7.xdc`, `pine_test.sv`, `ai_demo_data.svh`, and `out/` (bitstream and Vivado reports) |
| `vivado/` | `build.tcl` |
| `results/` | Simulation screenshots (N = 2, 4, 8, waveforms) and FPGA board photos / Vivado report excerpts |
| `earlier_work/` | Review 1 (2x2 design) and Review 2 (first UVM environment) code and outputs |
| `docs/` | Project report (black book), Review 1 report, Review 2 slides |

## Run the simulation (Cadence NCSim)
```
cd ncsim
source /home/install/cshrc            # lab tool setup
./run.sh 8 sva cov                    # N = 2, 4 or 8; add "waves" for a waveform database
```
`run.sh` copies `vectors_N<N>.svh` to `vectors.svh`, compiles everything with `-uvm -sv`, runs `matrix_full_test`, and prints the key lines.
The `*E,IMPDLL` message at the end is harmless.
Regenerate vectors: `python3 python/golden_model.py <N> [seed]` (writes the vector file for that array size).

## Build and program the FPGA (Vivado 2019.1)
From the repository root: `vivado -mode batch -source vivado/build.tcl -tclargs fpga_top`, then program `out/fpga_top.bit`
(a prebuilt copy is in `fpga/out/`). Board: PINE S7, clock G11 (100 MHz), KEY_0 = start, KEY_1 = reset, SW14 = mode (down = known-answer
test, up = live inference), LED16 = done. Slide switches read inverted on this board (`SW_INV = 1`).

## Notes
- Timing slack at 100 MHz is thin (+0.252 ns); the 8x8 multipliers use LUT/carry logic, not DSP slices.
- Reviews 1 and 2 used a fixed 2x2 design; see `earlier_work/`.
