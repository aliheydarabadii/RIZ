%% phase0_measurement_protocol.m
%
% Purpose:
%   Pre-experiment validation protocol for the two-RIS passive localization
%   setup. Run these sections in order before collecting localization data.
%   Each section is self-contained; run them individually with Ctrl+Enter.
%
% What you must edit:
%   - COM ports and Pluto RADIO_ID in the Hardware section below.
%   - idle_config_hex: the reference hex string for your idle RIS state.
%   - t_settle, discard_frames: match your RIS settling time.
%
% Hardware assumptions:
%   - Both RIS panels are powered and connected via serial.
%   - PlutoSDR is connected via USB.
%   - The room is accessible for manual reconfiguration between sections.

clc; clear; close all;

%% ===== Hardware – edit before running =====

COM_PORT_RIS1   = 'COM3';
COM_PORT_RIS2   = 'COM4';
BAUD_RATE       = 115200;
RADIO_ID        = 'usb:0';
fc              = 5000e6;
SamplingRate    = 1e6;
Gain            = 40;
SamplesPerFrame = 2^13;

idle_config_hex = '0000000000000000000000000000000000000000000000000000000000000000';
t_settle        = 5e-3;
discard_frames  = 3;

% Duration of each drift / stability measurement [seconds]
DRIFT_DURATION_S  = 60;
SETTLE_CONFIGS    = 5;    % configs to cycle during settling-time test
SETTLE_REPEATS    = 20;   % repetitions per config

%% ===== Init hardware (run once at session start) =====

rxPluto = sdrrx('Pluto', 'RadioID', RADIO_ID, ...
    'CenterFrequency', fc, 'GainSource', 'Manual', 'Gain', Gain, ...
    'OutputDataType', 'int16', 'BasebandSampleRate', SamplingRate, ...
    'SamplesPerFrame', SamplesPerFrame);

IRShandle1 = serialport(COM_PORT_RIS1, BAUD_RATE);
IRShandle2 = serialport(COM_PORT_RIS2, BAUD_RATE);

% Put both RIS in idle state
writeline(IRShandle1, "!0x" + idle_config_hex);
writeline(IRShandle2, "!0x" + idle_config_hex);
pause(0.1);
rxPluto(); rxPluto();
fprintf('Hardware initialised.\n');

%% ===== Section 1: Noise floor =====
% Purpose: confirm receiver is functioning; measure SNR floor with TX off.
%
% TODO: turn off the transmitter (or point it away from the RIS).

fprintf('\n--- Section 1: Noise floor ---\n');
N_samples = 100;
noise_rssi = zeros(N_samples, 1);
for k = 1:N_samples
    noise_rssi(k) = measure_rssi_pluto(rxPluto, 1);
end
fprintf('Noise floor: mean = %.2f dB,  std = %.2f dB\n', ...
    mean(noise_rssi), std(noise_rssi));

figure;
plot(noise_rssi); ylabel('RSSI (dB)'); xlabel('Sample');
title('Noise floor (TX off)'); grid on;

% TODO: turn the transmitter back on before proceeding.

%% ===== Section 2: Empty-room RSSI drift =====
% Purpose: quantify system drift over time with both RIS idle.
%
% TODO: clear the room of people.  Both RIS in idle state.

fprintf('\n--- Section 2: Empty-room drift (%d s) ---\n', DRIFT_DURATION_S);
t_end   = datetime('now') + seconds(DRIFT_DURATION_S);
drift_t = [];
drift_r = [];

while datetime('now') < t_end
    drift_t(end+1) = posixtime(datetime('now')); %#ok<SAGROW>
    drift_r(end+1) = measure_rssi_pluto(rxPluto, discard_frames); %#ok<SAGROW>
end

drift_t = drift_t - drift_t(1);
fprintf('Drift: range = %.2f dB,  std = %.2f dB\n', ...
    range(drift_r), std(drift_r));

figure;
plot(drift_t, drift_r); ylabel('RSSI (dB)'); xlabel('Time (s)');
title('Empty-room drift – both RIS idle'); grid on;

%% ===== Section 3: RIS settling time =====
% Purpose: determine how long the RIS needs after a serial command before
%          the RSSI reading is stable.  Use to calibrate t_settle.
%
% Both RIS idle.  TODO: clear the room.

fprintf('\n--- Section 3: RIS settling time ---\n');

% Load a small set of configs from the RIS1 beambook for this test
[~, ~, bb_test] = load_ris_beambook_csv('Beam_book_RIS1.csv');
test_configs = bb_test(1:min(SETTLE_CONFIGS, numel(bb_test)));

settle_data = zeros(SETTLE_REPEATS, length(test_configs));

for c = 1:length(test_configs)
    writeline(IRShandle1, "!0x" + test_configs{c});
    for r = 1:SETTLE_REPEATS
        raw_int16 = rxPluto();
        raw = single(raw_int16) / 2^11;
        settle_data(r, c) = pow2db(mean(abs(raw).^2));  % mean power → dB
    end
    writeline(IRShandle1, "!0x" + idle_config_hex);
    pause(0.05);
end

figure;
plot(settle_data);
xlabel('Frame index after command'); ylabel('RSSI (dB)');
title('RIS settling: RSSI vs frame number after config change');
legend(arrayfun(@(x) sprintf('config %d', x), 1:length(test_configs), 'UniformOutput', false));
grid on;
fprintf('Inspect the plot – choose t_settle so RSSI has stabilised.\n');

%% ===== Section 4: Total sweep time estimate =====
% Purpose: estimate time to complete one full two-RIS sweep.

fprintf('\n--- Section 4: Sweep time estimate ---\n');

[~, ~, bb1] = load_ris_beambook_csv('Beam_book_RIS1.csv');
n_configs_1 = numel(bb1);

[~, ~, bb2] = load_ris_beambook_csv('Beam_book_RIS2.csv');
n_configs_2 = numel(bb2);

t_per_config = t_settle + discard_frames * (SamplesPerFrame / SamplingRate);
t_sweep_1    = n_configs_1 * t_per_config;
t_sweep_2    = n_configs_2 * t_per_config;
fprintf('RIS1: %d configs × %.1f ms = %.1f s per sweep\n', ...
    n_configs_1, t_per_config*1e3, t_sweep_1);
fprintf('RIS2: %d configs × %.1f ms = %.1f s per sweep\n', ...
    n_configs_2, t_per_config*1e3, t_sweep_2);
fprintf('Full two-RIS sweep: %.1f s (× num_iter for averaging)\n', ...
    t_sweep_1 + t_sweep_2);

%% ===== Section 5: Idle RIS stability =====
% Purpose: confirm that the idle RIS config is stable and repeatable.
%
% TODO: clear the room.

fprintf('\n--- Section 5: Idle RIS stability ---\n');

% Toggle between idle and one active config to see how much idle state drifts
N_idle = 200;
rssi_idle = zeros(N_idle, 1);
writeline(IRShandle1, "!0x" + idle_config_hex);
writeline(IRShandle2, "!0x" + idle_config_hex);
pause(0.1);

for k = 1:N_idle
    rssi_idle(k) = measure_rssi_pluto(rxPluto, discard_frames);
end

fprintf('Idle state RSSI: mean = %.2f dB,  std = %.2f dB\n', ...
    mean(rssi_idle), std(rssi_idle));

figure;
plot(rssi_idle); ylabel('RSSI (dB)'); xlabel('Sample');
title('Idle RIS stability – both panels at idle config'); grid on;

%% ===== Section 6: Idle RIS footprint =====
% Purpose: measure how much RSSI the idle RIS state contributes relative to
%          having both RIS powered off (if possible).
%
% TODO: if possible, power off one RIS at a time and compare RSSI.

fprintf('\n--- Section 6: Idle RIS footprint ---\n');
fprintf('TODO: power off RIS1, measure RSSI.\n');
fprintf('TODO: power off RIS2, measure RSSI.\n');
fprintf('TODO: power off both, measure RSSI.\n');
fprintf('TODO: restore both to idle, measure RSSI.\n');
% Record values manually and compare to understand idle RIS leakage.

%% ===== Section 7: Human ΔRSSI quick test =====
% Purpose: confirm that a person in the ROI produces a detectable RSSI change.
%
% TODO: clear the room. Record empty baseline.
% TODO: person stands at ROI A. Record occupied RSSI.

fprintf('\n--- Section 7: Human delta-RSSI quick test ---\n');
fprintf('TODO: clear the room, then press Enter.\n');
input('');

N_meas = 50;
rssi_empty = zeros(N_meas, 1);
for k = 1:N_meas
    rssi_empty(k) = measure_rssi_pluto(rxPluto, discard_frames);
end
fprintf('Empty: mean = %.2f dB,  std = %.2f dB\n', ...
    mean(rssi_empty), std(rssi_empty));

fprintf('TODO: place subject at ROI A, then press Enter.\n');
input('');

rssi_occupied = zeros(N_meas, 1);
for k = 1:N_meas
    rssi_occupied(k) = measure_rssi_pluto(rxPluto, discard_frames);
end
fprintf('Occupied: mean = %.2f dB,  std = %.2f dB\n', ...
    mean(rssi_occupied), std(rssi_occupied));
fprintf('Delta: %.2f dB\n', mean(rssi_occupied) - mean(rssi_empty));

%% ===== Section 8: Idle RIS cross-perturbation =====
% Purpose: measure how much the idle RIS perturbs the active RIS sweep.
%          Compares RSSI with idle RIS present vs. absent (or covered).
%
% TODO: cover or remove the inactive RIS (e.g., absorber sheet).
% TODO: run a short beambook sweep and compare RSSI vs. idle RIS present.

fprintf('\n--- Section 8: Idle RIS cross-perturbation ---\n');
fprintf('TODO: run a partial sweep of RIS1 beambook with RIS2 idle.\n');
fprintf('TODO: cover/remove RIS2, repeat the same partial sweep.\n');
fprintf('TODO: compare the two RSSI heatmaps to quantify cross-perturbation.\n');
