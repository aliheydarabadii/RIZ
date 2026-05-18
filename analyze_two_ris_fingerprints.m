%% analyze_two_ris_fingerprints.m
%
% Purpose:
%   Offline analysis of time-multiplexed two-RIS RSSI measurements.
%   Builds per-location fingerprints from the two RIS conditions, computes
%   the separability metric J_sep, and prepares feature matrices for
%   classification.
%
% Inputs (edit the Data section below):
%   - One .mat file per location, produced by rx_pluto_two_ris_time_multiplexed.m
%   - Optionally: a separate empty-baseline .mat file for delta-RSSI correction
%
% Outputs (workspace):
%   x_RIS1      - N_locs × M1     mean fingerprint matrix, RIS1 condition
%   x_RIS2      - N_locs × M2     mean fingerprint matrix, RIS2 condition
%   x_twoRIS    - N_locs × (M1+M2) concatenated, independently normalised
%   J_sep       - struct with fields: RIS1, RIS2, twoRIS
%
% What you must edit:
%   - data_files: one .mat path per location
%   - location_labels: matching location names
%   - baseline_file: empty-room baseline .mat, or '' to skip
%
% J_sep note:
%   J_sep is an ordinal placement-ranking metric. Use it to compare feature
%   configurations (RIS1-only vs RIS2-only vs both) or sweep designs.
%   It is not an accuracy estimate.

clc; clear; close all;

%% ===== Data – edit before running =====

% One .mat file per measurement location.
data_files = {
    'exp01_results.mat',
    'exp02_results.mat',
};
location_labels = {'loc_A', 'loc_B'};

% Empty-room baseline (.mat in same format), or '' to skip.
%
% LIMITATION – global baseline only:
%   The current correction subtracts a single baseline mean from all
%   measurements.  This is adequate for early testing but not for the real
%   experiment, where system drift means you should subtract the temporally
%   nearest interleaved empty-room baseline instead.
%
%   TODO: add a condition "EMPTY_BASELINE" to the acquisition script so that
%   empty-room sweeps are interleaved with human measurements.
%   TODO: in this script, match each human measurement to its nearest baseline
%   by timestamp before subtracting.
baseline_file = '';

%% ===== Load data =====

N_locs = length(data_files);
assert(length(location_labels) == N_locs);

% Per-location cell arrays: each entry is n_iter × n_beams
fp_RIS1 = cell(N_locs, 1);
fp_RIS2 = cell(N_locs, 1);

for k = 1:N_locs
    d = load(data_files{k}, 'results');
    r = d.results;
    fp_RIS1{k} = extract_fingerprints(r, 'RIS1_ACTIVE_RIS2_IDLE');
    fp_RIS2{k} = extract_fingerprints(r, 'RIS2_ACTIVE_RIS1_IDLE');
end

%% ===== Baseline correction (optional) =====

if ~isempty(baseline_file)
    d0 = load(baseline_file, 'results');
    r0 = d0.results;
    base1 = mean(extract_fingerprints(r0, 'RIS1_ACTIVE_RIS2_IDLE'), 1);  % 1 × M1
    base2 = mean(extract_fingerprints(r0, 'RIS2_ACTIVE_RIS1_IDLE'), 1);  % 1 × M2
    for k = 1:N_locs
        fp_RIS1{k} = fp_RIS1{k} - base1;
        fp_RIS2{k} = fp_RIS2{k} - base2;
    end
    fprintf('Delta-RSSI baseline correction applied.\n');
end

%% ===== Mean fingerprint matrices =====
% x_RIS1, x_RIS2: N_locs × n_beams, one averaged fingerprint per location.

x_RIS1 = cell2mat(cellfun(@(f) mean(f,1), fp_RIS1, 'UniformOutput', false));
x_RIS2 = cell2mat(cellfun(@(f) mean(f,1), fp_RIS2, 'UniformOutput', false));

%% ===== Independent normalisation =====
% Normalise each RIS block separately to prevent one from dominating.

[x_RIS1_norm, mu1, sigma1] = zscore_safe(x_RIS1);
[x_RIS2_norm, mu2, sigma2] = zscore_safe(x_RIS2);
x_twoRIS = [x_RIS1_norm, x_RIS2_norm];

fprintf('Feature dimensions:\n');
fprintf('  x_RIS1:   %d locs × %d beams\n', size(x_RIS1,1), size(x_RIS1,2));
fprintf('  x_RIS2:   %d locs × %d beams\n', size(x_RIS2,1), size(x_RIS2,2));
fprintf('  x_twoRIS: %d locs × %d features\n', size(x_twoRIS,1), size(x_twoRIS,2));

%% ===== Separability metric J_sep =====
%
%   J_sep = sum_k ||mu_k - mu_bar||^2
%           ----------------------------------------
%           sum_k mean_r ||f_k^r - mu_k||^2 + epsilon
%
%   mu_k   = mean fingerprint for location k (across repetitions)
%   mu_bar = grand mean fingerprint
%   f_k^r  = fingerprint for repetition r at location k
%   epsilon = regularisation constant
%
%   Numerator:   between-location scatter  (larger = locations differ more)
%   Denominator: within-location scatter   (smaller = measurements repeatable)
%
% WARNING – exploratory / in-sample:
%   Normalisation parameters (mu, sigma) are computed from all loaded data,
%   so J_sep reflects in-sample separability.  Do not use this value as a
%   final placement performance estimate.
%
%   TODO: for final validation, split data into train / validation folds,
%   compute normalisation and location means on the train fold only, and
%   evaluate J_sep on the held-out validation fold.

epsilon = 1e-6;

% Normalise per-iteration fingerprints using the same mu/sigma as the means.
fp_RIS1_norm = normalise_with_params(fp_RIS1, mu1, sigma1);
fp_RIS2_norm = normalise_with_params(fp_RIS2, mu2, sigma2);
fp_two_norm  = cellfun(@(a,b) [a,b], fp_RIS1_norm, fp_RIS2_norm, 'UniformOutput', false);

J_sep.RIS1   = compute_jsep(x_RIS1_norm, fp_RIS1_norm, epsilon);
J_sep.RIS2   = compute_jsep(x_RIS2_norm, fp_RIS2_norm, epsilon);
J_sep.twoRIS = compute_jsep(x_twoRIS,    fp_two_norm,  epsilon);

fprintf('\nSeparability J_sep (higher = more separable):\n');
fprintf('  RIS1 only: %.4f\n', J_sep.RIS1);
fprintf('  RIS2 only: %.4f\n', J_sep.RIS2);
fprintf('  Two-RIS:   %.4f\n', J_sep.twoRIS);

%% ===== Visualise =====

figure;
imagesc(x_twoRIS); colorbar; colormap('parula');
xlabel('Feature index'); ylabel('Location');
title('Two-RIS fingerprint matrix (normalised)');
yticks(1:N_locs); yticklabels(location_labels);
set(findall(gcf, '-property', 'FontSize'), 'FontSize', 14);

%% ===== Classification placeholder =====

labels = location_labels(:);

% --- Option A: LDA (Statistics and Machine Learning Toolbox) ---
% mdl = fitcdiscr(x_twoRIS, labels);
% cv  = crossval(mdl);
% fprintf('LDA LOO error: %.1f%%\n', kfoldLoss(cv)*100);

% --- Option B: Random Forest (TreeBagger) ---
% B = TreeBagger(100, x_twoRIS, labels, 'OOBPrediction', 'on');
% fprintf('RF OOB error: %.1f%%\n', oobError(B,'Mode','ensemble')*100);

% --- Option C: Export to Python for XGBoost ---
% T_export = array2table(x_twoRIS);
% T_export.label = labels;
% writetable(T_export, 'features_for_python.csv');

%% ===== Helper functions =====

function F = extract_fingerprints(r, condition_str)
    % Return n_iter × n_beams matrix of RSSI fingerprints for one condition.
    mask      = strcmp(r.condition, condition_str);
    phi_idx   = r.phi_idx(mask);
    theta_idx = r.theta_idx(mask);
    rssi      = r.rssi_dB(mask);
    iter_idx  = r.iter(mask);

    n_phi   = max(phi_idx);
    n_theta = max(theta_idx);
    n_iter  = max(iter_idx);

    cube = nan(n_phi, n_theta, n_iter);  % NaN so missing entries don't become fake RSSI
    for idx = 1:sum(mask)
        cube(phi_idx(idx), theta_idx(idx), iter_idx(idx)) = rssi(idx);
    end
    if any(isnan(cube(:)))
        warning('extract_fingerprints: missing measurements in condition "%s".', condition_str);
    end
    % Each iteration → one row in F (1 × n_beams per iter)
    F = nan(n_iter, n_phi * n_theta);
    for it = 1:n_iter
        F(it,:) = reshape(cube(:,:,it), 1, []);
    end
end

function [Xn, mu, sigma] = zscore_safe(X)
    % z-score normalisation that avoids NaN for zero-variance (constant) beams.
    mu    = mean(X, 1);
    sigma = std(X, 0, 1);
    sigma(sigma == 0) = 1;   % constant beam: keep value at zero after mean subtraction
    Xn = (X - mu) ./ sigma;
end

function fp_norm = normalise_with_params(fp_cell, mu, sigma)
    % Apply pre-computed z-score parameters to per-iteration fingerprint data.
    fp_norm = cellfun(@(F) (F - mu) ./ sigma, fp_cell, 'UniformOutput', false);
end

function J = compute_jsep(X_mean, fp_norm_cell, epsilon)
    % J_sep from averaged location fingerprints and per-iteration data.
    % X_mean: N_locs × M,  fp_norm_cell: N_locs × 1 cell of (n_iter × M)
    N      = size(X_mean, 1);
    mu_bar = mean(X_mean, 1);

    between = sum(sum((X_mean - mu_bar).^2));   % sum_k ||mu_k - mu_bar||^2

    within = 0;
    for k = 1:N
        F    = fp_norm_cell{k};                 % n_iter × M
        mu_k = X_mean(k,:);                     % 1 × M
        within = within + mean(sum((F - mu_k).^2, 2));  % mean_r ||f_k^r - mu_k||^2
    end

    J = between / (within + epsilon);
end
