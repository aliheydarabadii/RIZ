function [rssi_dB, raw_frame] = measure_rssi_pluto(rxPluto, discard_frames)
%MEASURE_RSSI_PLUTO  Acquire one RSSI sample from a PlutoSDR object.
%
% Purpose:
%   Discard stale frames accumulated since the last call, then capture one
%   clean frame and return its RSSI.
%
% Inputs:
%   rxPluto        - configured sdrrx Pluto object
%   discard_frames - number of frames to flush before capturing (≥1 recommended
%                    after a serial command to allow the RIS to settle)
%
% Outputs:
%   rssi_dB   - 10*log10(mean(|normalised samples|^2)) in dB  (mean signal power)
%   raw_frame - captured I/Q samples as single, normalised to ±1 full-scale
%
% Note: the original rx_pluto_fast_RIS_beambook.m used mean(abs(x)) instead of
% mean(abs(x).^2). This function uses the correct power-based formula. Do not
% mix measurements from both scripts without re-collecting or re-labelling.

for k = 1:discard_frames
    rxPluto();
end

raw_int16 = rxPluto();
raw_frame = single(raw_int16) / 2^11;              % normalise int16 to [-1, 1] FS
rssi_dB   = pow2db(mean(abs(raw_frame).^2));       % mean power → dB
