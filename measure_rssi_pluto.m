function [rssi_dB, raw_frame] = measure_rssi_pluto(rxPluto, discard_frames)
%MEASURE_RSSI_PLUTO  Acquire one RSSI sample from a PlutoSDR object.
%
% Purpose:
%   Discard stale frames accumulated since the last call, then capture one
%   clean frame and return its RSSI. Matches the normalisation and RSSI
%   formula used in rx_pluto_fast_RIS_beambook.m for backward compatibility.
%
% Inputs:
%   rxPluto        - configured sdrrx Pluto object
%   discard_frames - number of frames to flush before capturing (≥1 recommended
%                    after a serial command to allow the RIS to settle)
%
% Outputs:
%   rssi_dB   - 10*log10(mean(|normalised samples|)) in dB
%               Note: this is mean-amplitude-in-dB, not mean-power-in-dB.
%               Consistent with the existing acquisition script.
%   raw_frame - captured I/Q samples as single, normalised to ±1 full-scale

for k = 1:discard_frames
    rxPluto();
end

raw_int16 = rxPluto();
raw_frame = single(raw_int16) / 2^11;        % normalise int16 to [-1, 1] FS
rssi_dB   = pow2db(mean(abs(raw_frame)));    % mean amplitude → dB
