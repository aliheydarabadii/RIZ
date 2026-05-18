function [theta_sweep, phi_sweep, beam_book] = load_ris_beambook_csv(path)
%LOAD_RIS_BEAMBOOK_CSV  Load a beambook CSV, preserving hex strings as text.
%
% Purpose:
%   Read a beambook CSV produced by generate_ris_beambook.m without letting
%   MATLAB auto-convert hex config strings to numbers. readcell() silently
%   drops leading zeros from numeric-looking strings (e.g. an all-zero config
%   '000...0' becomes 0), corrupting the serial command. This function reads
%   the file as plain text lines and only converts the angle headers to doubles.
%
% Requires MATLAB R2020b or later (uses readlines).
%
% Input:
%   path        - path to the CSV file
%
% Outputs:
%   theta_sweep - 1×Q double vector of azimuth angles [degrees]
%   phi_sweep   - P×1 double vector of elevation angles [degrees]
%   beam_book   - P×Q string matrix of 64-char hex config strings

if ~isfile(path)
    error('load_ris_beambook_csv: file not found: %s', path);
end

lines = readlines(path);
lines = lines(strtrim(lines) ~= "");    % drop blank trailing lines

% Row 1: [empty, theta_1, theta_2, ...]
header      = strsplit(lines(1), ',');
theta_sweep = str2double(header(2:end));   % 1×Q
n_theta     = length(theta_sweep);

% Rows 2…end: [phi_k, hex_1, hex_2, ...]
n_rows    = length(lines) - 1;
phi_sweep = zeros(n_rows, 1);
beam_book = strings(n_rows, n_theta);

for k = 1:n_rows
    parts = strsplit(lines(k + 1), ',');
    if length(parts) ~= n_theta + 1
        error('load_ris_beambook_csv: row %d has %d columns, expected %d. Check %s.', ...
            k + 1, length(parts), n_theta + 1, path);
    end
    phi_sweep(k)   = str2double(parts(1));
    beam_book(k,:) = strtrim(parts(2:end));   % kept as strings; no numeric conversion
end

% Validate: every config must be exactly 64 hexadecimal characters.
if any(strlength(beam_book(:)) ~= 64)
    error('load_ris_beambook_csv: all configs must be 64 characters. Check %s.', path);
end
if any(cellfun(@isempty, regexp(cellstr(beam_book(:)), '^[0-9A-Fa-f]{64}$', 'once')))
    error('load_ris_beambook_csv: configs must contain only hex characters [0-9A-Fa-f]. Check %s.', path);
end
