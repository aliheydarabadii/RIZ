clc; clear all; close all;

%% ============================================================
%  Two-RIS Pluto RSSI Measurement Script
%
%  Based on the one-RIS script, modified for:
%    1) RIS1 active, RIS2 idle
%    2) RIS2 active, RIS1 idle
%
%  This script does NOT sweep both RISs jointly.
%  It uses time-multiplexing:
%      RIS1 sweep while RIS2 idle
%      RIS2 sweep while RIS1 idle
%
%  Outputs:
%      Lab/<save_tag>_run_<N>.mat
%      Lab/<save_tag>_run_<N>.csv
%      Lab/<save_tag>_RIS1_active_avg_heatmap_run_<N>.png
%      Lab/<save_tag>_RIS2_active_avg_heatmap_run_<N>.png
%% ============================================================

%% ============================================================
%  User configuration
%% ============================================================

% ---------- Pluto parameters ----------
SamplingRate = 5e5;
fc           = 5000e6;

idRX = 'usb:0';   % Use this if only one Pluto is connected

PlutoGain        = 33;
SamplesPerFrame = 2^13;

% ---------- RIS serial ports ----------
% Your confirmed mapping:
% RIS1 -> /dev/cu.usbserial-D3B2Q9YP
% RIS2 -> /dev/cu.usbserial-D3AD02VH
COM_PORT_RIS1 = "/dev/cu.usbserial-D3AD02VH";
COM_PORT_RIS2 = "/dev/cu.usbserial-D3B2Q9YP";


BAUD_RATE = 115200;

% ---------- Beambook files ----------
input_path_ris1 = "Beam_book_RIS1.csv";
input_path_ris2 = "Beam_book_RIS2.csv";

% ---------- Idle/reference RIS configuration ----------
idle_config_hex = "0000000000000000000000000000000000000000000000000000000000000000";

% ---------- Measurement settings ----------
num_iter       = 10;     % number of repeated full sweeps
discard_frames = 3;     % Pluto frames to purge after RIS config change
t_settle       = 5e-3;  % pause after RIS serial command [s]

% ---------- Save settings ----------
save_tag = "empty_test_01";   % change later, e.g. "roi_A_test_01"
output_dir = "Lab";

% If true, the script repeats forever like the original supervisor script.
% If false, it runs only once.
RUN_CONTINUOUS = false;

%% ============================================================
%  Create output folder
%% ============================================================

if ~exist(output_dir, "dir")
    mkdir(output_dir);
end

%% ============================================================
%  Initialize Pluto
%% ============================================================

disp("Finding Pluto radio...");
radios = findPlutoRadio;
disp(radios);

disp("Creating Pluto RX object...");

rxPluto = sdrrx('Pluto', ...
    'RadioID', idRX, ...
    'CenterFrequency', fc, ...
    'GainSource', 'Manual', ...
    'Gain', PlutoGain, ...
    'OutputDataType', 'int16', ...
    'BasebandSampleRate', SamplingRate, ...
    'SamplesPerFrame', SamplesPerFrame);

%% ============================================================
%  Load RIS beambooks
%% ============================================================

disp("Loading RIS1 beambook...");
[theta_sweep_1, phi_sweep_1, beam_book_1] = load_beambook_csv(input_path_ris1);

disp("Loading RIS2 beambook...");
[theta_sweep_2, phi_sweep_2, beam_book_2] = load_beambook_csv(input_path_ris2);

disp("RIS1 theta_sweep:");
disp(theta_sweep_1);

disp("RIS1 phi_sweep:");
disp(phi_sweep_1);

disp("RIS1 beam_book size:");
disp(size(beam_book_1));

disp("RIS2 theta_sweep:");
disp(theta_sweep_2);

disp("RIS2 phi_sweep:");
disp(phi_sweep_2);

disp("RIS2 beam_book size:");
disp(size(beam_book_2));

%% ============================================================
%  Open serial connections to both RIS controllers
%% ============================================================

disp("Opening RIS serial ports...");

IRShandle1 = serialport(COM_PORT_RIS1, BAUD_RATE);
IRShandle2 = serialport(COM_PORT_RIS2, BAUD_RATE);

configureTerminator(IRShandle1, "LF");
configureTerminator(IRShandle2, "LF");

flush(IRShandle1);
flush(IRShandle2);

disp("RIS1 serial port:");
disp(COM_PORT_RIS1);

disp("RIS2 serial port:");
disp(COM_PORT_RIS2);

%% ============================================================
%  Initial Pluto purge
%% ============================================================

disp("Purging initial Pluto buffers...");
for k = 1:5
    rxPluto();
end

%% ============================================================
%  Set both RIS panels to idle before starting
%% ============================================================

disp("Setting both RIS panels to idle...");

send_ris_config(IRShandle1, idle_config_hex);
pause(t_settle);

send_ris_config(IRShandle2, idle_config_hex);
pause(t_settle);

disp("Both RIS panels are idle.");

input("Hardware ready. Press Enter to start measurement...");

%% ============================================================
%  Main acquisition loop
%% ============================================================

count_file = 0;

while true

    fprintf("\n============================================\n");
    fprintf("Starting acquisition run %d\n", count_file);
    fprintf("save_tag = %s\n", save_tag);
    fprintf("============================================\n");

    %% ------------------------------------------------------------
    %  Allocate RSSI maps
    %% ------------------------------------------------------------

    RSSI_image_RIS1 = zeros(length(phi_sweep_1), length(theta_sweep_1), num_iter);
    RSSI_image_RIS2 = zeros(length(phi_sweep_2), length(theta_sweep_2), num_iter);

    %% ------------------------------------------------------------
    %  Condition 1:
    %  RIS1 active, RIS2 idle
    %% ------------------------------------------------------------

    disp("============================================");
    disp("Condition 1: RIS1_ACTIVE_RIS2_IDLE");
    disp("============================================");

    % Put RIS2 in idle state
    send_ris_config(IRShandle2, idle_config_hex);
    pause(t_settle);

    % Purge Pluto after changing RIS2 state
    purge_pluto(rxPluto, discard_frames);

    tic;

    for count = 1:num_iter

        fprintf("\nRIS1 sweep repetition %d/%d\n", count, num_iter);

        for i = 1:length(phi_sweep_1)
            for j = 1:length(theta_sweep_1)

                config_hex = string(beam_book_1(i,j));

                % Load config onto RIS1
                send_ris_config(IRShandle1, config_hex);
                pause(t_settle);

                % Compute RSSI using Pluto, with buffer purge
                RSSI = measure_rssi_pluto(rxPluto, discard_frames);

                RSSI_image_RIS1(i,j,count) = RSSI;

                msg = "RIS1 active | iter " + num2str(count) + ...
                      " | phi=" + num2str(phi_sweep_1(i)) + ...
                      " | theta=" + num2str(theta_sweep_1(j)) + ...
                      " | RSSI=" + num2str(RSSI) + " dB";
                disp(msg);

            end
        end

        % Plot per-iteration heatmap for RIS1
        figure;
        imagesc(theta_sweep_1, phi_sweep_1, flipud(RSSI_image_RIS1(:,:,count)));
        colormap("cool");
        colorbar;
        xticks(theta_sweep_1);
        yticks(phi_sweep_1);
        ylabel('\phi_o (degrees)');
        xlabel('\theta_o (degrees)');
        title(['RIS1 active, RIS2 idle - RSSI Heatmap #', num2str(count)]);
        axis xy;
        axis equal tight;

    end

    toc;

    %% ------------------------------------------------------------
    %  Condition 2:
    %  RIS2 active, RIS1 idle
    %% ------------------------------------------------------------

    disp("============================================");
    disp("Condition 2: RIS2_ACTIVE_RIS1_IDLE");
    disp("============================================");

    % Put RIS1 in idle state
    send_ris_config(IRShandle1, idle_config_hex);
    pause(t_settle);

    % Purge Pluto after changing RIS1 state
    purge_pluto(rxPluto, discard_frames);

    tic;

    for count = 1:num_iter

        fprintf("\nRIS2 sweep repetition %d/%d\n", count, num_iter);

        for i = 1:length(phi_sweep_2)
            for j = 1:length(theta_sweep_2)

                config_hex = string(beam_book_2(i,j));

                % Load config onto RIS2
                send_ris_config(IRShandle2, config_hex);
                pause(t_settle);

                % Compute RSSI using Pluto, with buffer purge
                RSSI = measure_rssi_pluto(rxPluto, discard_frames);

                RSSI_image_RIS2(i,j,count) = RSSI;

                msg = "RIS2 active | iter " + num2str(count) + ...
                      " | phi=" + num2str(phi_sweep_2(i)) + ...
                      " | theta=" + num2str(theta_sweep_2(j)) + ...
                      " | RSSI=" + num2str(RSSI) + " dB";
                disp(msg);

            end
        end

        % Plot per-iteration heatmap for RIS2
        figure;
        imagesc(theta_sweep_2, phi_sweep_2, flipud(RSSI_image_RIS2(:,:,count)));
        colormap("cool");
        colorbar;
        xticks(theta_sweep_2);
        yticks(phi_sweep_2);
        ylabel('\phi_o (degrees)');
        xlabel('\theta_o (degrees)');
        title(['RIS2 active, RIS1 idle - RSSI Heatmap #', num2str(count)]);
        axis xy;
        axis equal tight;

    end

    toc;

    %% ------------------------------------------------------------
    %  Return both RIS panels to idle
    %% ------------------------------------------------------------

    disp("Returning both RIS panels to idle...");

    send_ris_config(IRShandle1, idle_config_hex);
    pause(t_settle);

    send_ris_config(IRShandle2, idle_config_hex);
    pause(t_settle);

    disp("Both RIS panels returned to idle.");

    %% ------------------------------------------------------------
    %  Average and variance
    %
    %  Average is computed in linear scale, then converted back to dB.
    %  Variance is computed on dB values directly for quick stability view.
    %% ------------------------------------------------------------

    RSSI_image_RIS1_linear = db2pow(RSSI_image_RIS1);
    RSSI_image_RIS2_linear = db2pow(RSSI_image_RIS2);

    RSSI_image_RIS1_avg = pow2db(mean(RSSI_image_RIS1_linear, 3));
    RSSI_image_RIS2_avg = pow2db(mean(RSSI_image_RIS2_linear, 3));

    RSSI_image_RIS1_var = var(RSSI_image_RIS1, 0, 3);
    RSSI_image_RIS2_var = var(RSSI_image_RIS2, 0, 3);

    %% ------------------------------------------------------------
    %  Plot average RSSI heatmap - RIS1 active
    %% ------------------------------------------------------------

    fig1 = figure;
    imagesc(theta_sweep_1, phi_sweep_1, flipud(RSSI_image_RIS1_avg));
    colormap("cool");
    cb = colorbar;
    cb.Label.String = 'RSSI (dB)';
    xticks(theta_sweep_1);
    yticks(phi_sweep_1);
    ylabel('$\varphi_o^\circ$ (deg.)', 'Interpreter','latex');
    xlabel('$\theta_o^\circ$ (deg.)', 'Interpreter','latex');
    title('RIS1 active, RIS2 idle - Average RSSI', 'Interpreter','latex');
    axis xy;
    axis equal tight;
    set(findall(fig1, '-property', 'FontSize'), 'FontSize', 24);

    %% ------------------------------------------------------------
    %  Plot average RSSI heatmap - RIS2 active
    %% ------------------------------------------------------------

    fig2 = figure;
    imagesc(theta_sweep_2, phi_sweep_2, flipud(RSSI_image_RIS2_avg));
    colormap("cool");
    cb = colorbar;
    cb.Label.String = 'RSSI (dB)';
    xticks(theta_sweep_2);
    yticks(phi_sweep_2);
    ylabel('$\varphi_o^\circ$ (deg.)', 'Interpreter','latex');
    xlabel('$\theta_o^\circ$ (deg.)', 'Interpreter','latex');
    title('RIS2 active, RIS1 idle - Average RSSI', 'Interpreter','latex');
    axis xy;
    axis equal tight;
    set(findall(fig2, '-property', 'FontSize'), 'FontSize', 24);

    %% ------------------------------------------------------------
    %  Plot variance maps
    %% ------------------------------------------------------------

    fig3 = figure;
    bar3(flipud(RSSI_image_RIS1_var) * 1e4, 1);
    set(gca, 'XTickLabel', theta_sweep_1);
    set(gca, 'YTickLabel', phi_sweep_1);
    ylabel('$\varphi_o^\circ$ (deg.)', 'Interpreter','latex');
    xlabel('$\theta_o^\circ$ (deg.)', 'Interpreter','latex');
    title('RIS1 active, RIS2 idle - RSSI variance x 10^4', 'Interpreter','latex');
    axis xy;
    axis equal tight;
    set(findall(fig3, '-property', 'FontSize'), 'FontSize', 24);

    fig4 = figure;
    bar3(flipud(RSSI_image_RIS2_var) * 1e4, 1);
    set(gca, 'XTickLabel', theta_sweep_2);
    set(gca, 'YTickLabel', phi_sweep_2);
    ylabel('$\varphi_o^\circ$ (deg.)', 'Interpreter','latex');
    xlabel('$\theta_o^\circ$ (deg.)', 'Interpreter','latex');
    title('RIS2 active, RIS1 idle - RSSI variance x 10^4', 'Interpreter','latex');
    axis xy;
    axis equal tight;
    set(findall(fig4, '-property', 'FontSize'), 'FontSize', 24);

    %% ------------------------------------------------------------
    %  Build flat CSV table
    %% ------------------------------------------------------------

    T = table();

    row = 1;

    for iter = 1:num_iter
        for i = 1:length(phi_sweep_1)
            for j = 1:length(theta_sweep_1)

                T.timestamp(row,1)  = string(datetime("now", "Format", "yyyy-MM-dd HH:mm:ss.SSS"));
                T.condition(row,1)  = "RIS1_ACTIVE_RIS2_IDLE";
                T.active_ris(row,1) = 1;
                T.iter(row,1)       = iter;
                T.phi_idx(row,1)    = i;
                T.theta_idx(row,1)  = j;
                T.phi_deg(row,1)    = phi_sweep_1(i);
                T.theta_deg(row,1)  = theta_sweep_1(j);
                T.config_hex(row,1) = string(beam_book_1(i,j));
                T.rssi_dB(row,1)    = RSSI_image_RIS1(i,j,iter);

                row = row + 1;

            end
        end
    end

    for iter = 1:num_iter
        for i = 1:length(phi_sweep_2)
            for j = 1:length(theta_sweep_2)

                T.timestamp(row,1)  = string(datetime("now", "Format", "yyyy-MM-dd HH:mm:ss.SSS"));
                T.condition(row,1)  = "RIS2_ACTIVE_RIS1_IDLE";
                T.active_ris(row,1) = 2;
                T.iter(row,1)       = iter;
                T.phi_idx(row,1)    = i;
                T.theta_idx(row,1)  = j;
                T.phi_deg(row,1)    = phi_sweep_2(i);
                T.theta_deg(row,1)  = theta_sweep_2(j);
                T.config_hex(row,1) = string(beam_book_2(i,j));
                T.rssi_dB(row,1)    = RSSI_image_RIS2(i,j,iter);

                row = row + 1;

            end
        end
    end

    %% ------------------------------------------------------------
    %  Save data
    %% ------------------------------------------------------------

    mat_file = fullfile(output_dir, save_tag + "_run_" + num2str(count_file) + ".mat");
    csv_file = fullfile(output_dir, save_tag + "_run_" + num2str(count_file) + ".csv");

    save(mat_file, ...
        'RSSI_image_RIS1', ...
        'RSSI_image_RIS2', ...
        'RSSI_image_RIS1_avg', ...
        'RSSI_image_RIS2_avg', ...
        'RSSI_image_RIS1_var', ...
        'RSSI_image_RIS2_var', ...
        'theta_sweep_1', ...
        'phi_sweep_1', ...
        'theta_sweep_2', ...
        'phi_sweep_2', ...
        'beam_book_1', ...
        'beam_book_2', ...
        'idle_config_hex', ...
        'SamplingRate', ...
        'fc', ...
        'PlutoGain', ...
        'SamplesPerFrame', ...
        'discard_frames', ...
        't_settle', ...
        'num_iter', ...
        'COM_PORT_RIS1', ...
        'COM_PORT_RIS2', ...
        'T');

    writetable(T, csv_file);

    fig1_file = fullfile(output_dir, save_tag + "_RIS1_active_avg_heatmap_run_" + num2str(count_file) + ".png");
    fig2_file = fullfile(output_dir, save_tag + "_RIS2_active_avg_heatmap_run_" + num2str(count_file) + ".png");
    fig3_file = fullfile(output_dir, save_tag + "_RIS1_active_variance_run_" + num2str(count_file) + ".png");
    fig4_file = fullfile(output_dir, save_tag + "_RIS2_active_variance_run_" + num2str(count_file) + ".png");

    saveas(fig1, fig1_file);
    saveas(fig2, fig2_file);
    saveas(fig3, fig3_file);
    saveas(fig4, fig4_file);

    fprintf("\nSaved files:\n");
    fprintf("MAT: %s\n", mat_file);
    fprintf("CSV: %s\n", csv_file);
    fprintf("FIG: %s\n", fig1_file);
    fprintf("FIG: %s\n", fig2_file);
    fprintf("FIG: %s\n", fig3_file);
    fprintf("FIG: %s\n", fig4_file);

    count_file = count_file + 1;

    %% ------------------------------------------------------------
    %  Continue or stop
    %% ------------------------------------------------------------

    if ~RUN_CONTINUOUS
        disp("RUN_CONTINUOUS = false, stopping after one acquisition.");
        break;
    end

    user_answer = input("Press Enter to run another acquisition, or type q to quit: ", "s");

    if strcmpi(strtrim(user_answer), "q")
        break;
    end

end

%% ============================================================
%  Cleanup
%% ============================================================

disp("Releasing Pluto and serial handles...");

try
    release(rxPluto);
catch
end

clear IRShandle1 IRShandle2;

disp("Done.");

%% ============================================================
%  Local functions
%% ============================================================

function [theta_sweep, phi_sweep, beam_book] = load_beambook_csv(input_path)

    if ~isfile(input_path)
        error("Beambook file not found: %s", input_path);
    end

    % Read first row manually to extract theta_sweep
    fid = fopen(input_path, 'r');

    if fid < 0
        error("Could not open file: %s", input_path);
    end

    header_line = fgetl(fid);
    fclose(fid);

    header_parts = strsplit(header_line, ',');

    % header_parts(1) is empty, skip it
    theta_sweep = str2double(header_parts(2:end));
    theta_sweep = theta_sweep(~isnan(theta_sweep));

    % Read rest of file as text
    opts = detectImportOptions(input_path, ...
        'NumHeaderLines', 1, ...
        'VariableNamingRule', 'preserve');

    opts = setvartype(opts, repmat({'char'}, 1, length(opts.VariableNames)));

    raw = readtable(input_path, opts);

    % First column is phi_sweep
    phi_col = table2array(raw(:,1));

    if iscell(phi_col)
        phi_sweep = str2double(phi_col);
    else
        phi_sweep = double(phi_col);
    end

    phi_sweep = phi_sweep(~isnan(phi_sweep));

    % Remove first column, remaining entries are hex configs
    raw(:,1) = [];
    beam_book = string(table2array(raw));

    % Validate dimensions
    if size(beam_book, 1) ~= length(phi_sweep)
        error("Mismatch: number of phi values does not match beambook rows.");
    end

    if size(beam_book, 2) ~= length(theta_sweep)
        error("Mismatch: number of theta values does not match beambook columns.");
    end

    % Validate all hex configurations
    for i = 1:size(beam_book,1)
        for j = 1:size(beam_book,2)
            validate_hex64(beam_book(i,j), ...
                "beambook entry (" + num2str(i) + "," + num2str(j) + ")");
        end
    end

end

function send_ris_config(IRShandle, config_hex)

    config_hex = upper(string(strtrim(config_hex)));
    validate_hex64(config_hex, "RIS config");

    cmd = "!0x" + config_hex;
    writeline(IRShandle, cmd);

end

function validate_hex64(config_hex, label)

    config_hex = upper(string(strtrim(config_hex)));

    if strlength(config_hex) ~= 64
        error("%s must be exactly 64 hex characters. Got %d.", ...
            label, strlength(config_hex));
    end

    if isempty(regexp(char(config_hex), '^[0-9A-F]{64}$', 'once'))
        error("%s contains invalid hex characters.", label);
    end

end

function purge_pluto(rxPluto, discard_frames)

    for k = 1:discard_frames
        rxPluto();
    end

end

function RSSI = measure_rssi_pluto(rxPluto, discard_frames)

    % Purge old Pluto buffers
    for k = 1:discard_frames
        rxPluto();
    end

    % Read measurement frame
    rxWave = rxPluto();

    % Convert int16 to single, same style as original script
    rxWave = single(rxWave) / 2^11;

    % Compute RSSI
    RSSI = pow2db(mean(abs(rxWave.^2)));

end