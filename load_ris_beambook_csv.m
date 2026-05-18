function [theta_sweep, phi_sweep, beam_book] = load_ris_beambook_csv(path)
%LOAD_RIS_BEAMBOOK_CSV  Load a beambook CSV produced by generate_ris_beambook.m.
%
% Purpose:
%   Robustly read a mixed numeric/string beambook CSV using readcell, which
%   handles the header row (theta angles) and header column (phi angles)
%   without the type-coercion issues that readtable/table2array can produce.
%
% Input:
%   path        - path to the CSV file
%
% Outputs:
%   theta_sweep - 1×Q double vector of azimuth angles [degrees]
%   phi_sweep   - P×1 double vector of elevation angles [degrees]
%   beam_book   - P×Q string matrix of 64-char hex config strings

raw = readcell(path);

theta_sweep = cell2mat(raw(1, 2:end));          % 1×Q doubles from first row
phi_sweep   = cell2mat(raw(2:end, 1));          % P×1 doubles from first col
beam_book   = string(raw(2:end, 2:end));        % P×Q hex strings
