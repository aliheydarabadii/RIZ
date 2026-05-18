%% generate_two_ris_beambooks.m
%
% Purpose:
%   Generate independent beambooks for RIS1 and RIS2.
%   Each RIS gets its own CSV (and optional .mat) file, using the same
%   fixed transmitter but potentially different panel geometry and sweep grids.
%
% Outputs:
%   Beam_book_RIS1.csv / beambook_RIS1.mat
%   Beam_book_RIS2.csv / beambook_RIS2.mat
%
% What you must edit:
%   - RIS geometry (dy, dz) to match your physical panels.
%   - tx.theta / tx.phi to match the actual transmitter direction.
%   - theta_sweep / phi_sweep for each RIS (angular coverage of interest).
%
% Prerequisite: generate_ris_beambook.m must be on the MATLAB path.

clc; clear; close all;

%% ===== Shared parameters =====

f_c = 5.4e9;   % carrier frequency [Hz]

% Fixed transmitter direction (shared by both RIS)
tx.theta = deg2rad(0);   % azimuth  [rad]
tx.phi   = deg2rad(0);   % elevation [rad]

% Reference receiver direction (metadata only, not used in phase computation)
rx.theta = deg2rad(0);
rx.phi   = deg2rad(0);

%% ===== RIS 1 geometry =====

RIS1.f_c  = f_c;
RIS1.Ntot = 16;
RIS1.Mtot = 16;
RIS1.dy   = 20e-3;   % horizontal element spacing [m]
RIS1.dz   = 13e-3;   % vertical   element spacing [m]

theta_sweep_1 = deg2rad(-60:10:60);   % azimuth  sweep [rad]
phi_sweep_1   = deg2rad(-15:15:15);   % elevation sweep [rad]

%% ===== RIS 2 geometry =====

RIS2.f_c  = f_c;
RIS2.Ntot = 16;
RIS2.Mtot = 16;
RIS2.dy   = 20e-3;
RIS2.dz   = 13e-3;

theta_sweep_2 = deg2rad(-60:10:60);
phi_sweep_2   = deg2rad(-15:15:15);

%% ===== Generate beambooks =====

fprintf('--- Generating RIS1 beambook ---\n');
generate_ris_beambook(RIS1, tx, rx, theta_sweep_1, phi_sweep_1, ...
    'Beam_book_RIS1.csv', 'beambook_RIS1.mat');

fprintf('--- Generating RIS2 beambook ---\n');
generate_ris_beambook(RIS2, tx, rx, theta_sweep_2, phi_sweep_2, ...
    'Beam_book_RIS2.csv', 'beambook_RIS2.mat');

fprintf('\nDone.\n');
fprintf('  Beam_book_RIS1.csv / beambook_RIS1.mat\n');
fprintf('  Beam_book_RIS2.csv / beambook_RIS2.mat\n');
