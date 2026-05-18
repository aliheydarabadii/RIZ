%% rx_pluto_two_ris_time_multiplexed.m
%
% Purpose:
%   Time-multiplexed RSSI acquisition for a two-RIS passive localization
%   experiment.  Each condition is measured independently:
%     RIS1_ACTIVE_RIS2_IDLE  – RIS1 sweeps its beambook, RIS2 held at idle
%     RIS2_ACTIVE_RIS1_IDLE  – RIS2 sweeps its beambook, RIS1 held at idle
%
%   Results are saved per-measurement with timestamps and condition labels.
%
% Inputs (edit the Configuration section below):
%   Beam_book_RIS1.csv, Beam_book_RIS2.csv  (from generate_two_ris_beambooks.m)
%
% Outputs:
%   <save_tag>_results.mat   – results struct + metadata
%   <save_tag>_results.csv   – flat table for easy import / analysis
%
% What you must edit before running:
%   - COM_PORT_RIS1 / COM_PORT_RIS2: serial port names for each controller
%   - RADIO_ID: Pluto USB/serial identifier
%   - fc, SamplingRate, Gain: RF parameters
%   - idle_config_hex: 64-char hex string for the idle/reference RIS state
%   - t_settle: pause after serial command [seconds]
%   - discard_frames: SDR frames to flush after each config change
%   - num_iter: number of full sweeps per condition
%   - save_tag: prefix for output files
%   - DRY_RUN: set true to test the save/load/analysis pipeline without hardware
%
% Hardware assumptions:
%   - RIS controllers accept serial commands as "!0x<64-char-hex>" at 115200 baud
%   - Both RIS are powered and responsive before the script runs
%   - The RIS does NOT settle instantaneously; t_settle and discard_frames
%     together form the guard interval after each configuration change

clc; clear; close all;

%% ===== Configuration – edit before running =====

DRY_RUN = false;  % true → synthetic RSSI, no hardware needed (for pipeline testing)

% --- Serial ports ---
COM_PORT_RIS1 = 'COM3';      % Windows: 'COM3'  Mac: '/dev/tty.usbserial-XXXX'
COM_PORT_RIS2 = 'COM4';
BAUD_RATE     = 115200;

% --- PlutoSDR ---
RADIO_ID        = 'usb:0';
fc              = 5000e6;    % centre frequency [Hz]
SamplingRate    = 1e6;       % baseband sample rate [Hz]
Gain            = 40;        % RX gain [dB]
SamplesPerFrame = 2^13;

% --- Idle/reference RIS configuration ---
% 64-char hex string sent to the inactive RIS during each condition.
idle_config_hex = '0000000000000000000000000000000000000000000000000000000000000000';

% --- Timing ---
t_settle       = 5e-3;   % pause after serial write [s]
discard_frames = 3;      % SDR frames to flush after config change

% --- Experiment ---
num_iter        = 3;       % repetitions of the full beambook sweep
save_tag        = 'exp01'; % prefix for output files
run_ris1_active = true;
run_ris2_active = true;

% --- Beambook paths ---
path_bb_ris1 = 'Beam_book_RIS1.csv';
path_bb_ris2 = 'Beam_book_RIS2.csv';

%% ===== Load beambooks =====

[theta_sweep_1, phi_sweep_1, beam_book_1] = load_ris_beambook_csv(path_bb_ris1);
[theta_sweep_2, phi_sweep_2, beam_book_2] = load_ris_beambook_csv(path_bb_ris2);

fprintf('RIS1 beambook: %d phi × %d theta\n', length(phi_sweep_1), length(theta_sweep_1));
fprintf('RIS2 beambook: %d phi × %d theta\n', length(phi_sweep_2), length(theta_sweep_2));

%% ===== Initialise hardware =====

if ~DRY_RUN
    rxPluto = sdrrx('Pluto', 'RadioID', RADIO_ID, ...
        'CenterFrequency',  fc, ...
        'GainSource',       'Manual', ...
        'Gain',             Gain, ...
        'OutputDataType',   'int16', ...
        'BasebandSampleRate', SamplingRate, ...
        'SamplesPerFrame',  SamplesPerFrame);

    IRShandle1 = serialport(COM_PORT_RIS1, BAUD_RATE);
    IRShandle2 = serialport(COM_PORT_RIS2, BAUD_RATE);
    fprintf('Serial ports open: %s (RIS1), %s (RIS2)\n', COM_PORT_RIS1, COM_PORT_RIS2);

    rxPluto(); rxPluto();
    input('Hardware ready. Press Enter to start measurements...');

    % Release hardware automatically if the script errors or is interrupted.
    cleanupObj = onCleanup(@() cleanup_hardware(rxPluto, IRShandle1, IRShandle2)); %#ok<NASGU>
else
    warning('DRY_RUN enabled – no hardware used. RSSI values are synthetic.');
end

%% ===== Pre-allocate results =====

n_ris1  = length(phi_sweep_1) * length(theta_sweep_1);
n_ris2  = length(phi_sweep_2) * length(theta_sweep_2);
n_total = num_iter * (run_ris1_active * n_ris1 + run_ris2_active * n_ris2);

results = struct( ...
    'timestamp',  repmat("", n_total, 1), ...
    'condition',  repmat("", n_total, 1), ...
    'active_ris', zeros(n_total, 1), ...
    'iter',       zeros(n_total, 1), ...
    'phi_idx',    zeros(n_total, 1), ...
    'theta_idx',  zeros(n_total, 1), ...
    'phi_deg',    zeros(n_total, 1), ...
    'theta_deg',  zeros(n_total, 1), ...
    'rssi_dB',    zeros(n_total, 1));

row = 1;

%% ===== Condition 1: RIS1 active, RIS2 idle =====

if run_ris1_active
    fprintf('\n=== Condition: RIS1_ACTIVE_RIS2_IDLE ===\n');

    if ~DRY_RUN
        writeline(IRShandle2, "!0x" + idle_config_hex);
        pause(t_settle);
    end

    for iter = 1:num_iter
        fprintf('  Iteration %d/%d\n', iter, num_iter);
        tic

        for i = 1:length(phi_sweep_1)
            for j = 1:length(theta_sweep_1)

                if ~DRY_RUN
                    writeline(IRShandle1, "!0x" + beam_book_1(i,j));
                    pause(t_settle);
                    rssi = measure_rssi_pluto(rxPluto, discard_frames);
                else
                    rssi = -60 + 5*rand() - 2*rand()*iter;  % synthetic
                end

                results.timestamp(row)  = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS'));
                results.condition(row)  = "RIS1_ACTIVE_RIS2_IDLE";
                results.active_ris(row) = 1;
                results.iter(row)       = iter;
                results.phi_idx(row)    = i;
                results.theta_idx(row)  = j;
                results.phi_deg(row)    = phi_sweep_1(i);
                results.theta_deg(row)  = theta_sweep_1(j);
                results.rssi_dB(row)    = rssi;
                row = row + 1;
            end
        end

        toc
    end
end

%% ===== Condition 2: RIS2 active, RIS1 idle =====

if run_ris2_active
    fprintf('\n=== Condition: RIS2_ACTIVE_RIS1_IDLE ===\n');

    if ~DRY_RUN
        writeline(IRShandle1, "!0x" + idle_config_hex);
        pause(t_settle);
    end

    for iter = 1:num_iter
        fprintf('  Iteration %d/%d\n', iter, num_iter);
        tic

        for i = 1:length(phi_sweep_2)
            for j = 1:length(theta_sweep_2)

                if ~DRY_RUN
                    writeline(IRShandle2, "!0x" + beam_book_2(i,j));
                    pause(t_settle);
                    rssi = measure_rssi_pluto(rxPluto, discard_frames);
                else
                    rssi = -58 + 4*rand() - 1.5*rand()*iter;  % synthetic
                end

                results.timestamp(row)  = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS'));
                results.condition(row)  = "RIS2_ACTIVE_RIS1_IDLE";
                results.active_ris(row) = 2;
                results.iter(row)       = iter;
                results.phi_idx(row)    = i;
                results.theta_idx(row)  = j;
                results.phi_deg(row)    = phi_sweep_2(i);
                results.theta_deg(row)  = theta_sweep_2(j);
                results.rssi_dB(row)    = rssi;
                row = row + 1;
            end
        end

        toc
    end
end

%% ===== Save results =====

% Trim pre-allocated arrays to actual number of rows collected.
% Using an explicit loop so results stays a scalar struct with vector fields,
% compatible with struct2table() and analyze_two_ris_fingerprints.m.
fields = fieldnames(results);
for f = 1:numel(fields)
    results.(fields{f}) = results.(fields{f})(1:row-1);
end

mat_path = [save_tag '_results.mat'];
save(mat_path, 'results', 'num_iter', 'idle_config_hex', ...
    'theta_sweep_1', 'phi_sweep_1', 'theta_sweep_2', 'phi_sweep_2', ...
    'fc', 'SamplingRate', 'Gain', 'DRY_RUN');
fprintf('\nResults saved to %s\n', mat_path);

T = struct2table(results);
csv_path = [save_tag '_results.csv'];
writetable(T, csv_path);
fprintf('CSV saved to %s\n', csv_path);

%% ===== Quick-look RSSI heatmaps =====

dry_suffix = "";
if DRY_RUN
    dry_suffix = " [DRY RUN]";
end

if run_ris1_active
    mask     = results.condition == "RIS1_ACTIVE_RIS2_IDLE";
    rssi_1   = results.rssi_dB(mask);
    rssi_map_1 = reshape(mean(reshape(rssi_1, n_ris1, num_iter), 2), ...
        length(phi_sweep_1), length(theta_sweep_1));

    figure;
    imagesc(theta_sweep_1, phi_sweep_1, rssi_map_1);
    colormap('cool'); colorbar;
    xlabel('\theta_o (deg)'); ylabel('\phi_o (deg)');
    title("RIS1 active – avg RSSI heatmap" + dry_suffix);
    axis xy; axis equal tight;
    set(findall(gcf, '-property', 'FontSize'), 'FontSize', 14);
end

if run_ris2_active
    mask     = results.condition == "RIS2_ACTIVE_RIS1_IDLE";
    rssi_2   = results.rssi_dB(mask);
    rssi_map_2 = reshape(mean(reshape(rssi_2, n_ris2, num_iter), 2), ...
        length(phi_sweep_2), length(theta_sweep_2));

    figure;
    imagesc(theta_sweep_2, phi_sweep_2, rssi_map_2);
    colormap('cool'); colorbar;
    xlabel('\theta_o (deg)'); ylabel('\phi_o (deg)');
    title("RIS2 active – avg RSSI heatmap" + dry_suffix);
    axis xy; axis equal tight;
    set(findall(gcf, '-property', 'FontSize'), 'FontSize', 14);
end

%% ===== Explicit hardware cleanup =====
% onCleanup inside a script may not fire immediately because script variables
% persist in the base workspace. This block ensures resources are released.

if ~DRY_RUN
    try; release(rxPluto); catch; end
    clear IRShandle1 IRShandle2 cleanupObj;
end

%% ===== Local functions =====

function cleanup_hardware(rxPluto, IRShandle1, IRShandle2)
    % Called automatically by onCleanup if the script errors or is interrupted.
    try; release(rxPluto);   catch; end
    try; clear IRShandle1;   catch; end
    try; clear IRShandle2;   catch; end
end
