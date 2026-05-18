# RIS Passive Localization – MATLAB Toolkit

MATLAB scripts for passive localization experiments using one or two Reconfigurable Intelligent Surfaces (RIS). The RIS is a 16×16 element panel operating at 5.4 GHz with 1-bit phase control (0 or π per element), controlled over serial and measured with an ADALM-PLUTO SDR.

---

## Hardware

| Component | Details |
|---|---|
| RIS panel | 16×16 elements, 20 mm horizontal / 13 mm vertical spacing, 5.4 GHz |
| SDR | ADALM-PLUTO (PlutoSDR), connected via USB |
| RIS controller | Serial interface at 115200 baud, command format `!0x<64-char-hex>` |
| Transmitter | Fixed position; direction set via `tx.theta` / `tx.phi` |

---

## File overview

### Beambook generation

| File | Purpose |
|---|---|
| `generate_ris_beambook.m` | Core function — generates a 1-bit beambook for one RIS and writes a CSV |
| `generate_two_ris_beambooks.m` | Wrapper script — calls the function for RIS1 and RIS2 |
| `Beam_Book_RIS.m` | Original one-RIS script (fixed TX, sweep RX) → `Beam_book_0.csv` |
| `Beam_Book_RIS_V2.m` | Original one-RIS script (fixed RX, sweep TX) → `Beam_book_rx_0_d.csv` |

### Acquisition

| File | Purpose |
|---|---|
| `rx_pluto_two_ris_time_multiplexed.m` | Two-RIS time-multiplexed RSSI sweep with per-measurement logging |
| `rx_pluto_fast_RIS_beambook.m` | Original one-RIS acquisition script |
| `measure_rssi_pluto.m` | Utility function — flush frames, capture one, return RSSI in dB |

### Analysis and utilities

| File | Purpose |
|---|---|
| `analyze_two_ris_fingerprints.m` | Build fingerprints, compute J_sep, export for classification |
| `phase0_measurement_protocol.m` | Pre-experiment validation (noise floor, drift, settling time, etc.) |
| `Beam_patter_3D.m` | Single-config beam pattern analysis across five quantization levels |
| `set_config.m` | Interactive: enter a hex string, visualise beam pattern and received power |
| `plot_BP.m` | Beam pattern visualization helper |
| `plot_Pr.m` | Received power visualization helper |

---

## Workflow

### Step 1 — Generate beambooks

Edit geometry and sweep parameters in `generate_two_ris_beambooks.m`, then run it:

```matlab
run('generate_two_ris_beambooks.m')
```

Outputs: `Beam_book_RIS1.csv`, `Beam_book_RIS2.csv` (and matching `.mat` files).

### Step 2 — Pre-experiment validation (Phase 0)

Run sections of `phase0_measurement_protocol.m` interactively before any localization data collection. Key checks: noise floor, empty-room drift, RIS settling time, human ΔRSSI, idle-RIS cross-perturbation.

### Step 3 — Collect measurements

Edit the **Configuration** block at the top of `rx_pluto_two_ris_time_multiplexed.m`:

```matlab
COM_PORT_RIS1   = 'COM3';        % serial port for RIS1 controller
COM_PORT_RIS2   = 'COM4';        % serial port for RIS2 controller
RADIO_ID        = 'usb:0';       % PlutoSDR identifier
idle_config_hex = '0000...';     % 64-char hex for the inactive RIS
t_settle        = 5e-3;          % seconds to wait after each serial command
discard_frames  = 3;             % SDR frames to flush after config change
num_iter        = 3;             % sweep repetitions
save_tag        = 'exp01';       % output file prefix
```

Run the script once per location. Outputs: `<save_tag>_results.mat` and `<save_tag>_results.csv`.

### Step 4 — Offline analysis

Edit `analyze_two_ris_fingerprints.m` to list the per-location `.mat` files:

```matlab
data_files      = {'exp01_results.mat', 'exp02_results.mat', ...};
location_labels = {'loc_A', 'loc_B', ...};
baseline_file   = '';   % optional empty-room baseline
```

The script computes mean fingerprints (`x_RIS1`, `x_RIS2`, `x_twoRIS`), separability J_sep, and includes placeholder sections for LDA, Random Forest, and Python/XGBoost export.

---

## RIS configuration encoding

Each RIS state is a 64-character hexadecimal string encoding the 16×16 binary phase map:

1. Compute the continuous phase shift for each element: `phase = -(k_in + k_out) · r_mn`
2. Quantise to 1-bit: phase ∈ [−π/2, π/2) → state 0 (+1); otherwise → state π (−1)
3. Convert to bits, apply NOT-inversion (firmware maps 0-bit → π-state)
4. Reshape to 16×16, flatten row-major, group into 4-bit nibbles → 64 hex chars

The serial command format is `!0x<64-char-hex>` at 115200 baud.

---

## Key parameters to check before each experiment

- `RIS.dy` / `RIS.dz` — physical element spacing (default: 20 mm / 13 mm)
- `tx.theta` / `tx.phi` — transmitter direction in radians
- `fc` — carrier frequency (default: 5.4 GHz for beambooks, 5.0 GHz for PlutoSDR)
- `idle_config_hex` — reference state for the inactive RIS
- Serial COM ports — differ between Windows (`COM3`) and macOS (`/dev/tty.usbserial-*`)
- `t_settle` — increase if RSSI is not stable after a config change (check Section 3 of Phase 0)
