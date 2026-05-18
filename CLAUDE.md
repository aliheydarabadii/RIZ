# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

MATLAB codebase for Reconfigurable Intelligent Surface (RIS) research. The RIS is a 16×16 element passive array (256 elements total) operating at 5.4 GHz with 1-bit phase control per element (0 or π phase shift). Physical element spacing: 20 mm horizontal (`dy`), 13 mm vertical (`dz`).

## Running scripts

Open MATLAB and run scripts directly (e.g., `run('Beam_patter_3D.m')`). There is no build system, linter, or test framework. Requires the MATLAB Phased Array System Toolbox (`physconst`, `patternCustom`) and Communications Toolbox for the SDR script.

For hardware measurements (`rx_pluto_fast_RIS_beambook.m`), the ADALM-PLUTO SDR support package must be installed.

## Architecture and data flow

**Beam book generation (offline)**
1. `Beam_Book_RIS.m` — Fixed TX, sweeps RX angles → outputs `Beam_book_0.csv`
2. `Beam_Book_RIS_V2.m` — Fixed RX, sweeps TX angles → outputs `Beam_book_rx_0_d.csv` and `beambook_d1_doub1_near.mat`
3. `Beam_patter_3D.m` — Single-config analysis: computes beam patterns for five quantization levels (continuous, 1-bit [−π/2,π/2], 1-bit [0,π], 2-bit, 2-bit offset), then received power over a spatial grid → outputs `config.txt` and `config.mat` with the 1-bit [0,π] configuration

**Hex configuration encoding**
RIS state is encoded as a 64-character hex string (256 bits = 16×16 elements, 4 bits per hex char):
- Compute continuous phase shift vector `vTrue` (256×1 complex)
- Quantize: elements with `angle(vTrue) ∈ [−π/2, π/2)` → 1 (phase 0); others → −1 (phase π)
- Convert to binary: `vTrue_bin = (vTrue == 1)`, then invert (`not(vTrue_bin)`)
- Reshape to 16×16, flatten row-major to 256 bits, group into 4-bit nibbles, convert each to hex

This inversion (NOT) is intentional — the hardware interprets 0-bit as the π state.

**Hardware deployment**
`rx_pluto_fast_RIS_beambook.m` loads a beam book CSV, iterates over all angle configurations, sends each hex config to the RIS controller via serial (`writeline(IRShandle, "!0x" + config)`) and measures RSSI from a PlutoSDR. The serial port (`COM3` or `/dev/tty.usbserial-*`) must be updated for the host system.

**Helper functions**
- `set_config.m` — Interactive: prompts for a 64-char hex string, decodes it, plots beam pattern + received power distribution (3-panel figure)
- `plot_BP.m` — Tiled figure of beam patterns and phase maps for multiple quantization schemes
- `plot_Pr.m` — Tiled figure of received power over the xy-plane scenario

## Key conventions

- Angle convention: `theta` = azimuth, `phi` = elevation, both in radians internally, degrees in plots
- Beam pattern normalization: `1/(Ntot * Mtot) * conj(vTrue).' * vTry`
- Element indexing uses 0-based vectors (`Nvec = 0:Ntot-1`, `Mvec = 0:Mtot-1`) in beam book scripts, but `set_config.m` uses centered indexing (`-N/2:N/2-1`)
- The beam book CSV layout: first row = theta values (degrees), first column = phi values (degrees), interior cells = hex config strings
