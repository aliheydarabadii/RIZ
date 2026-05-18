function [Beam_book_cell, config_bin_cell, BP_cell, vTrue_cell] = ...
    generate_ris_beambook(RIS, tx, rx, theta_sweep, phi_sweep, output_csv, mat_file)
%GENERATE_RIS_BEAMBOOK  1-bit [0, pi] beambook for a single RIS.
%
% Purpose:
%   For each (theta, phi) pair in the sweep grid, compute the 1-bit RIS
%   phase configuration that redirects the wave arriving from the fixed TX
%   direction toward that steering direction. Pack the result as a 64-char
%   hex string and save a CSV beambook compatible with the acquisition
%   scripts.
%
% Inputs:
%   RIS         - struct: f_c [Hz], Ntot, Mtot, dy [m], dz [m]
%   tx          - struct: theta [rad], phi [rad]  (fixed incident direction)
%   rx          - struct: theta [rad], phi [rad]  (reference, stored in .mat only)
%   theta_sweep - 1×Q azimuth  angles to sweep [rad]
%   phi_sweep   - 1×P elevation angles to sweep [rad]
%   output_csv  - path for the output CSV file
%   mat_file    - (optional) path for .mat file; omit or '' to skip
%
% Outputs:
%   Beam_book_cell  - P×Q cell of 64-char hex config strings
%   config_bin_cell - P×Q cell of 64×4 binary nibble arrays
%   BP_cell         - P×Q cell of beam-pattern matrices (181 phi × 181 theta)
%   vTrue_cell      - P×Q cell of 256×1 quantized phase vectors (±1)
%
% What you must edit before calling:
%   - RIS.dy / RIS.dz: physical element spacing of your panel
%   - tx.theta / tx.phi: actual transmitter direction
%   - output_csv: writable path for the CSV
%
% Hardware assumption:
%   Elements numbered row-major; hex packing uses NOT-inversion so that a
%   0-bit maps to the pi-phase state on the OpenRIS firmware.

if nargin < 7
    mat_file = '';
end

c      = physconst('lightspeed');
lambda = c / RIS.f_c;
Ntot   = RIS.Ntot;
Mtot   = RIS.Mtot;

Nvec = 0:Ntot-1;
Mvec = 0:Mtot-1;
[N, M] = meshgrid(Nvec, Mvec);
N = reshape(N, [], 1);   % 256×1
M = reshape(M, [], 1);   % 256×1

% Fine angular grid for beam-pattern evaluation (not stored in CSV)
thetaTry = deg2rad(-90:90);   % 1×181
phiTry   = deg2rad(-90:90);   % 1×181

BP_cell         = cell(length(phi_sweep), length(theta_sweep));
vTrue_cell      = cell(length(phi_sweep), length(theta_sweep));
Beam_book_cell  = cell(length(phi_sweep), length(theta_sweep));
config_bin_cell = cell(length(phi_sweep), length(theta_sweep));

for i = 1:numel(phi_sweep)
    for j = 1:numel(theta_sweep)

        PHI   = phi_sweep(i);
        THETA = theta_sweep(j);

        % Continuous phase shift for element (m,n):
        %   phase = -(k_in + k_out) · r_mn
        % where k_in is the incident wave vector from TX and k_out points
        % toward the desired steering direction (THETA, PHI).
        %   r_mn = [M*dy, 0, N*dz]  (horizontal, depth, vertical)
        vTrue = exp(-1j * 2*pi/lambda * ...
            ( (M*RIS.dy*sin(tx.theta)*cos(tx.phi) + N*RIS.dz*sin(tx.phi)) ...
            + (M*RIS.dy*sin(THETA)*cos(PHI)       + N*RIS.dz*sin(PHI)) ));

        % 1-bit quantization [0, pi]:
        %   phase in [-pi/2, pi/2) → 0-state (+1)
        %   all others             → pi-state (-1)
        vQ = vTrue;
        in_zero_state = angle(vTrue) >= -pi/2 & angle(vTrue) < pi/2;
        vQ( in_zero_state) =  1;
        vQ(~in_zero_state) = -1;
        vTrue_cell{i,j} = vQ;

        % Evaluate normalised beam pattern over the full angular grid.
        % vTry is 256×181 (matrix mul: (256×1)*(1×181) + implicit expansion).
        p = 1;
        for phi = phiTry
            vTry = exp(-1j * 2*pi/lambda * ...
                ( (M*RIS.dy*sin(tx.theta)*cos(tx.phi) + N*RIS.dz*sin(tx.phi)) ...
                + (M*RIS.dy*sin(thetaTry)*cos(phi)    + N*RIS.dz*sin(phi)) ));
            BP_cell{i,j}(p,:) = (1/Ntot) * (1/Mtot) * conj(vQ).' * vTry;
            p = p + 1;
        end

        % Hex packing (must match OpenRIS firmware convention):
        %   1. vQ == 1  →  logical true  (0-phase elements)
        %   2. NOT-invert: firmware interprets 0-bit as pi-state
        %   3. Reshape to 16×16, flatten row-major, group into 4-bit nibbles,
        %      convert to hex characters → 64-char string
        vTrue_bin            = (vQ == 1);
        bits_inv             = reshape(~vTrue_bin, Ntot, Mtot);
        bits_flat            = reshape(bits_inv, 1, []);
        config_bin_cell{i,j} = reshape(bits_flat, 4, [])';           % 64×4
        Beam_book_cell{i,j}  = string(dec2hex(bin2dec(num2str(config_bin_cell{i,j})))');
    end
end

% --- Build and write CSV ---
% Layout: row 1 = [NaN, theta_deg...], col 1 = [NaN; phi_deg...], interior = hex strings
data          = cell(length(phi_sweep) + 1, length(theta_sweep) + 1);
data(1, 2:end) = num2cell(rad2deg(theta_sweep));
data(2:end, 1) = num2cell(rad2deg(phi_sweep));
for i = 1:length(phi_sweep)
    for j = 1:length(theta_sweep)
        data{i+1, j+1} = Beam_book_cell{i,j};
    end
end
writetable(cell2table(data), output_csv, 'WriteVariableNames', false);
fprintf('Beambook saved: %s  (%d phi × %d theta = %d configs)\n', ...
    output_csv, length(phi_sweep), length(theta_sweep), ...
    numel(phi_sweep) * numel(theta_sweep));

% --- Optionally save .mat ---
if ~isempty(mat_file)
    save(mat_file, 'data', 'phi_sweep', 'theta_sweep', ...
        'Beam_book_cell', 'config_bin_cell', 'vTrue_cell', 'RIS', 'tx', 'rx');
    fprintf('Metadata saved: %s\n', mat_file);
end
