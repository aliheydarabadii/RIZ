%% generate_two_ris_beambooks.m
%
% Purpose:
%   Generate independent beambooks for RIS1 and RIS2.
%
%   RIS1 and RIS2 can have different transmitter/antenna incidence angles.
%   In this version:
%       RIS1 sees the antenna at 0 degrees.
%       RIS2 sees the antenna at 60 degrees.
%
% Outputs:
%   Beam_book_RIS1.csv / beambook_RIS1.mat
%   Beam_book_RIS2.csv / beambook_RIS2.mat
%
% Plot outputs:
%   RIS1_beam_patterns_readable.png          if BP_cell exists
%   RIS1_RIS_configurations_readable.png
%   RIS2_beam_patterns_readable.png          if BP_cell exists
%   RIS2_RIS_configurations_readable.png
%
% Prerequisite:
%   generate_ris_beambook.m must be on the MATLAB path.

clc; clear; close all;

%% ============================================================
%  LIMITATION: angle-based only, not coordinate/placement-aware
%% ============================================================
%
% This script manually sets the transmitter incidence angle for each RIS.
% It does NOT compute the angles from real room coordinates.
%
% For now:
%   RIS1 incident angle = 0 degrees
%   RIS2 incident angle = 60 degrees
%
% Later, for a placement-aware version, you should add:
%
%   RIS1.pos    = [x1, y1, z1];
%   RIS1.normal = [nx1, ny1, nz1];
%   RIS2.pos    = [x2, y2, z2];
%   RIS2.normal = [nx2, ny2, nz2];
%   tx.pos      = [x_tx, y_tx, z_tx];
%   rx.pos      = [x_rx, y_rx, z_rx];

%% ============================================================
%  Shared RF parameter
%% ============================================================

% Match this with your Pluto TX/RX center frequency.
% If your experiment is really at 5.4 GHz, change this back to 5.4e9.
f_c = 5.0e9;   % carrier frequency [Hz]

%% ============================================================
%  Transmitter / antenna incidence angle for each RIS
%% ============================================================

% RIS1 sees the antenna at 0 degrees.
tx1.theta = deg2rad(0);
tx1.phi   = deg2rad(0);

% RIS2 sees the antenna at 60 degrees.
tx2.theta = deg2rad(60);
tx2.phi   = deg2rad(0);

% Reference receiver direction.
% In the current generate_ris_beambook implementation this is mostly metadata.
rx.theta = deg2rad(0);
rx.phi   = deg2rad(0);

%% ============================================================
%  RIS 1 geometry
%% ============================================================

RIS1.f_c  = f_c;
RIS1.Ntot = 16;
RIS1.Mtot = 16;
RIS1.dy   = 20e-3;   % horizontal element spacing [m]
RIS1.dz   = 13e-3;   % vertical element spacing [m]

% RIS1 output steering sweep.
% theta = -40, -30, -20, -10, 0, 10, 20, 30, 40 degrees
theta_sweep_1 = deg2rad(-40:10:40);
phi_sweep_1   = deg2rad(0);

%% ============================================================
%  RIS 2 geometry
%% ============================================================

RIS2.f_c  = f_c;
RIS2.Ntot = 16;
RIS2.Mtot = 16;
RIS2.dy   = 20e-3;
RIS2.dz   = 13e-3;

% RIS2 output steering sweep.
% Same output sweep as RIS1, but different incident antenna angle.
theta_sweep_2 = deg2rad(-40:10:40);
phi_sweep_2   = deg2rad(0);

%% ============================================================
%  Print configuration summary
%% ============================================================

fprintf('\n=== Two-RIS beambook generation ===\n');
fprintf('Carrier frequency: %.3f GHz\n', f_c / 1e9);

fprintf('\nRIS1:\n');
fprintf('  TX incidence theta = %.1f deg\n', rad2deg(tx1.theta));
fprintf('  TX incidence phi   = %.1f deg\n', rad2deg(tx1.phi));
fprintf('  Output theta sweep = ');
fprintf('%.0f ', rad2deg(theta_sweep_1));
fprintf('deg\n');
fprintf('  Output phi sweep   = ');
fprintf('%.0f ', rad2deg(phi_sweep_1));
fprintf('deg\n');

fprintf('\nRIS2:\n');
fprintf('  TX incidence theta = %.1f deg\n', rad2deg(tx2.theta));
fprintf('  TX incidence phi   = %.1f deg\n', rad2deg(tx2.phi));
fprintf('  Output theta sweep = ');
fprintf('%.0f ', rad2deg(theta_sweep_2));
fprintf('deg\n');
fprintf('  Output phi sweep   = ');
fprintf('%.0f ', rad2deg(phi_sweep_2));
fprintf('deg\n\n');

%% ============================================================
%  Generate beambooks
%% ============================================================

fprintf('--- Generating RIS1 beambook ---\n');

generate_ris_beambook(RIS1, tx1, rx, theta_sweep_1, phi_sweep_1, ...
    'Beam_book_RIS1.csv', 'beambook_RIS1.mat');

fprintf('--- Generating RIS2 beambook ---\n');

generate_ris_beambook(RIS2, tx2, rx, theta_sweep_2, phi_sweep_2, ...
    'Beam_book_RIS2.csv', 'beambook_RIS2.mat');

%% ============================================================
%  Plot readable beam patterns and RIS configurations
%% ============================================================

fprintf('\n--- Plotting RIS1 beam patterns and RIS configurations ---\n');

plot_beambook_patterns_and_configs( ...
    "beambook_RIS1.mat", ...
    "Beam_book_RIS1.csv", ...
    RIS1, ...
    "RIS1");

fprintf('\n--- Plotting RIS2 beam patterns and RIS configurations ---\n');

plot_beambook_patterns_and_configs( ...
    "beambook_RIS2.mat", ...
    "Beam_book_RIS2.csv", ...
    RIS2, ...
    "RIS2");

%% ============================================================
%  Done
%% ============================================================

fprintf('\nDone.\n');
fprintf('Generated files:\n');
fprintf('  Beam_book_RIS1.csv\n');
fprintf('  beambook_RIS1.mat\n');
fprintf('  Beam_book_RIS2.csv\n');
fprintf('  beambook_RIS2.mat\n');

fprintf('\nGenerated readable plots:\n');
fprintf('  RIS1_RIS_configurations_readable.png\n');
fprintf('  RIS2_RIS_configurations_readable.png\n');
fprintf('  RIS1_beam_patterns_readable.png if BP_cell exists\n');
fprintf('  RIS2_beam_patterns_readable.png if BP_cell exists\n');

fprintf('\nExpected CSV header:\n');
fprintf('  ,-40,-30,-20,-10,0,10,20,30,40\n');

%% ============================================================
%  Local functions
%% ============================================================

function plot_beambook_patterns_and_configs(mat_file, csv_file, RIS, label)

    %% ------------------------------------------------------------
    %  Load CSV because it always exists after generation
    %% ------------------------------------------------------------

    [theta_sweep_csv, phi_sweep_csv, beam_book_csv] = load_beambook_csv_local(csv_file);

    %% ------------------------------------------------------------
    %  Load MAT file if available
    %% ------------------------------------------------------------

    if isfile(mat_file)
        S = load(mat_file);

        fprintf("Loaded %s\n", mat_file);
        fprintf("Variables inside %s:\n", mat_file);
        disp(fieldnames(S));
    else
        warning("MAT file not found: %s. Only CSV-based configuration plots will be generated.", mat_file);
        S = struct();
    end

    %% ------------------------------------------------------------
    %  Use MAT sweeps if available, otherwise CSV sweeps
    %% ------------------------------------------------------------

    if isfield(S, "theta_sweep")
        theta_sweep_rad = S.theta_sweep;
    else
        theta_sweep_rad = deg2rad(theta_sweep_csv);
    end

    if isfield(S, "phi_sweep")
        phi_sweep_rad = S.phi_sweep;
    else
        phi_sweep_rad = deg2rad(phi_sweep_csv);
    end

    %% ------------------------------------------------------------
    %  Plot beam patterns if BP_cell exists
    %% ------------------------------------------------------------

    has_bp = isfield(S, "BP_cell") && ...
             isfield(S, "thetaTry") && ...
             isfield(S, "phiTry");

    if has_bp

        BP_cell  = S.BP_cell;
        thetaTry = S.thetaTry;
        phiTry   = S.phiTry;

        num_cfg = numel(BP_cell);

        nCols = ceil(sqrt(num_cfg));
        nRows = ceil(num_cfg / nCols);

        fig_bp = figure( ...
            "Name", label + " beam patterns", ...
            "Color", "w", ...
            "Position", [100 100 1700 950]);

        tl = tiledlayout(nRows, nCols, ...
            "TileSpacing", "compact", ...
            "Padding", "compact");

        tile_idx = 1;

        for ii = 1:size(BP_cell, 1)
            for jj = 1:size(BP_cell, 2)

                ax = nexttile(tile_idx);
                tile_idx = tile_idx + 1;

                BP = BP_cell{ii, jj};

                BP_abs = abs(BP);
                BP_dB = 20 * log10(BP_abs ./ max(BP_abs(:)) + eps);

                imagesc(ax, rad2deg(thetaTry), rad2deg(phiTry), BP_dB);
                clim(ax, [-60 0]);

                axis(ax, "square");
                grid(ax, "on");
                hold(ax, "on");
                set(ax, "YDir", "normal");

                plot(ax, ...
                    rad2deg(theta_sweep_rad(jj)), ...
                    rad2deg(phi_sweep_rad(ii)), ...
                    "r*", ...
                    "MarkerSize", 8, ...
                    "LineWidth", 1.5);

                hold(ax, "off");

                title(ax, sprintf('\\theta_0 = %.0f^\\circ, \\phi_0 = %.0f^\\circ', ...
                    rad2deg(theta_sweep_rad(jj)), ...
                    rad2deg(phi_sweep_rad(ii))), ...
                    "FontSize", 11, ...
                    "Interpreter", "tex");

                xlabel(ax, "\theta [deg]");
                ylabel(ax, "\phi [deg]");

            end
        end

        colormap(fig_bp, "parula");

        cb = colorbar;
        cb.Layout.Tile = "east";
        cb.Label.String = "Normalized beam pattern [dB]";

        sgtitle(tl, label + " beam patterns", ...
            "FontSize", 22, ...
            "FontWeight", "bold");

        exportgraphics(fig_bp, label + "_beam_patterns_readable.png", ...
            "Resolution", 300);

        fprintf("Saved %s\n", label + "_beam_patterns_readable.png");

    else
        warning("%s does not contain BP_cell/thetaTry/phiTry. Beam-pattern plot skipped.", mat_file);
    end

    %% ------------------------------------------------------------
    %  Plot RIS configurations in readable 3x3-style grid
    %% ------------------------------------------------------------

    fprintf("Plotting readable RIS configuration grid for %s...\n", label);

    num_cfg = numel(theta_sweep_csv) * numel(phi_sweep_csv);

    nCols = ceil(sqrt(num_cfg));
    nRows = ceil(num_cfg / nCols);

    fig_cfg = figure( ...
        "Name", label + " RIS configurations", ...
        "Color", "w", ...
        "Position", [100 100 1700 950]);

    tl = tiledlayout(nRows, nCols, ...
        "TileSpacing", "compact", ...
        "Padding", "compact");

    tile_idx = 1;

    %% ------------------------------------------------------------
    %  Option A: use vTrue_cell if available
    %% ------------------------------------------------------------

    if isfield(S, "vTrue_cell")

        fprintf("Using vTrue_cell from %s for RIS configuration plot.\n", mat_file);

        vTrue_cell = S.vTrue_cell;

        for ii = 1:size(vTrue_cell, 1)
            for jj = 1:size(vTrue_cell, 2)

                ax = nexttile(tile_idx);
                tile_idx = tile_idx + 1;

                v = vTrue_cell{ii, jj};

                phase_map = angle(reshape(v, RIS.Ntot, RIS.Mtot)).';

                imagesc(ax, phase_map);

                axis(ax, "image");
                axis(ax, "off");
                clim(ax, [-pi pi]);

                title(ax, sprintf('\\theta = %.0f^\\circ, \\phi = %.0f^\\circ', ...
                    rad2deg(theta_sweep_rad(jj)), ...
                    rad2deg(phi_sweep_rad(ii))), ...
                    "FontSize", 12, ...
                    "Interpreter", "tex");

            end
        end

        colormap(fig_cfg, "parula");

        cb = colorbar;
        cb.Layout.Tile = "east";
        cb.Label.String = "RIS phase [rad]";

    %% ------------------------------------------------------------
    %  Option B: reconstruct phase maps from CSV hex strings
    %% ------------------------------------------------------------

    else

        fprintf("vTrue_cell not found in %s. Reconstructing RIS configurations from CSV hex.\n", mat_file);

        for ii = 1:size(beam_book_csv, 1)
            for jj = 1:size(beam_book_csv, 2)

                ax = nexttile(tile_idx);
                tile_idx = tile_idx + 1;

                hex_config = string(beam_book_csv(ii, jj));

                bit_map = hex64_to_bit_matrix(hex_config, RIS.Ntot, RIS.Mtot);

                % 1-bit RIS phase interpretation:
                % bit 0 -> phase 0
                % bit 1 -> phase pi
                phase_map = bit_map * pi;

                imagesc(ax, phase_map);

                axis(ax, "image");
                axis(ax, "off");
                clim(ax, [0 pi]);

                title(ax, sprintf('\\theta = %.0f^\\circ, \\phi = %.0f^\\circ', ...
                    theta_sweep_csv(jj), ...
                    phi_sweep_csv(ii)), ...
                    "FontSize", 12, ...
                    "Interpreter", "tex");

            end
        end

        colormap(fig_cfg, parula(2));

        cb = colorbar;
        cb.Layout.Tile = "east";
        cb.Ticks = [0 pi];
        cb.TickLabels = {'0', '\pi'};
        cb.Label.String = "RIS phase state";

    end

    sgtitle(tl, label + " RIS phase configurations", ...
        "FontSize", 22, ...
        "FontWeight", "bold");

    exportgraphics(fig_cfg, label + "_RIS_configurations_readable.png", ...
        "Resolution", 300);

    fprintf("Saved %s\n", label + "_RIS_configurations_readable.png");

    %% ------------------------------------------------------------
    %  Optional: save individual configuration images
    %% ------------------------------------------------------------

    save_individual_configs = true;

    if save_individual_configs

        out_dir = label + "_individual_configs";

        if ~exist(out_dir, "dir")
            mkdir(out_dir);
        end

        for ii = 1:size(beam_book_csv, 1)
            for jj = 1:size(beam_book_csv, 2)

                hex_config = string(beam_book_csv(ii, jj));

                bit_map = hex64_to_bit_matrix(hex_config, RIS.Ntot, RIS.Mtot);
                phase_map = bit_map * pi;

                fig_single = figure( ...
                    "Visible", "off", ...
                    "Color", "w", ...
                    "Position", [100 100 650 600]);

                imagesc(phase_map);
                axis image;
                axis off;
                clim([0 pi]);
                colormap(parula(2));

                cb = colorbar;
                cb.Ticks = [0 pi];
                cb.TickLabels = {'0', '\pi'};
                cb.Label.String = "RIS phase state";

                title(sprintf('%s configuration: \\theta = %.0f^\\circ, \\phi = %.0f^\\circ', ...
                    label, theta_sweep_csv(jj), phi_sweep_csv(ii)), ...
                    "FontSize", 16, ...
                    "Interpreter", "tex");

                file_name = sprintf("%s_theta_%+03.0f_phi_%+03.0f.png", ...
                    label, theta_sweep_csv(jj), phi_sweep_csv(ii));

                file_name = replace(file_name, "+", "p");
                file_name = replace(file_name, "-", "m");

                exportgraphics(fig_single, fullfile(out_dir, file_name), ...
                    "Resolution", 300);

                close(fig_single);

            end
        end

        fprintf("Saved individual configuration images in folder: %s\n", out_dir);

    end

end

function bit_map = hex64_to_bit_matrix(hex_config, Ntot, Mtot)

    hex_config = upper(string(strtrim(hex_config)));

    if strlength(hex_config) ~= 64
        error("RIS configuration must be exactly 64 hex characters. Got %d.", ...
            strlength(hex_config));
    end

    if isempty(regexp(char(hex_config), '^[0-9A-F]{64}$', 'once'))
        error("RIS configuration contains non-hex characters.");
    end

    bit_string = "";

    for k = 1:64
        h = extractBetween(hex_config, k, k);
        bit_string = bit_string + string(dec2bin(hex2dec(char(h)), 4));
    end

    bits = double(char(bit_string) - '0');

    if numel(bits) ~= Ntot * Mtot
        error("Expected %d bits, got %d bits.", Ntot * Mtot, numel(bits));
    end

    % Same orientation style as:
    % angle(reshape(vTrue_cell{ii,jj}, RIS.Ntot, RIS.Mtot))'
    bit_map = reshape(bits, Ntot, Mtot).';

end

function [theta_sweep, phi_sweep, beam_book] = load_beambook_csv_local(input_path)

    if ~isfile(input_path)
        error("Beambook file not found: %s", input_path);
    end

    % Read first row manually to extract theta_sweep.
    fid = fopen(input_path, 'r');

    if fid < 0
        error("Could not open file: %s", input_path);
    end

    header_line = fgetl(fid);
    fclose(fid);

    header_parts = strsplit(header_line, ',');

    % First entry is empty because header starts with comma.
    theta_sweep = str2double(header_parts(2:end));
    theta_sweep = theta_sweep(~isnan(theta_sweep));

    % Read remaining rows as text.
    opts = detectImportOptions(input_path, ...
        'NumHeaderLines', 1, ...
        'VariableNamingRule', 'preserve');

    opts = setvartype(opts, repmat({'char'}, 1, length(opts.VariableNames)));

    raw = readtable(input_path, opts);

    % First column is phi.
    phi_col = table2array(raw(:,1));

    if iscell(phi_col)
        phi_sweep = str2double(phi_col);
    else
        phi_sweep = double(phi_col);
    end

    phi_sweep = phi_sweep(~isnan(phi_sweep));

    % Remaining columns are hex configurations.
    raw(:,1) = [];
    beam_book = string(table2array(raw));

end