clc; clear; close all;

%% ============================================================
%  Pluto TX: continuous 100 kHz tone at 5 GHz center frequency
%
%  RF output frequency approximately:
%      fc + tone_freq = 5 GHz + 100 kHz
%
%  This version guarantees that the repeated waveform contains
%  an integer number of tone cycles, so transmitRepeat() has no
%  phase discontinuity at the buffer boundary.
%% ============================================================

%% Find connected Pluto
radios = findPlutoRadio;
disp(radios);

%% Pluto TX parameters
idTX = 'usb:0';

fc = 5000e6;             % RF center frequency = 5 GHz
SamplingRate = 1e6;      % baseband sample rate = 1 MS/s
tone_freq = 100e3;       % 100 kHz baseband tone

tx_gain = 0;             % TX gain in dB
amplitude = 0.90;        % keep below 1 to avoid clipping

%% ============================================================
%  Generate gapless periodic waveform
%% ============================================================

% Number of samples per tone period
samples_per_period = SamplingRate / abs(tone_freq);

% Check that tone frequency is compatible with sample rate
if abs(samples_per_period - round(samples_per_period)) > 1e-12
    error("tone_freq must divide SamplingRate exactly for a perfectly periodic buffer.");
end

samples_per_period = round(samples_per_period);

% Choose how many complete cycles to store in the buffer
num_cycles = 1000;

% Total number of samples: exactly an integer number of cycles
N = samples_per_period * num_cycles;

n = (0:N-1).';

% Complex baseband tone
txWave = amplitude * exp(1j * 2*pi*tone_freq*n/SamplingRate);

% Convert to single precision for Pluto
txWave = single(txWave);

%% Verify periodicity
first_sample = txWave(1);
next_after_buffer = amplitude * exp(1j * 2*pi*tone_freq*N/SamplingRate);

phase_error = abs(first_sample - single(next_after_buffer));

fprintf("Samples per period: %d\n", samples_per_period);
fprintf("Number of cycles in buffer: %d\n", num_cycles);
fprintf("Total waveform samples: %d\n", N);
fprintf("Boundary phase error: %.3e\n", phase_error);

if phase_error > 1e-6
    warning("Waveform may not be perfectly periodic at the repeat boundary.");
else
    disp("Waveform is periodic. No phase jump at repeat boundary.");
end

%% Optional: plot a few samples
figure;
plot(real(txWave(1:100)), '-o');
grid on;
xlabel("Sample index");
ylabel("Amplitude");
title("Real part of 100 kHz baseband tone");

%% ============================================================
%  Create Pluto TX object
%% ============================================================

txPluto = sdrtx('Pluto', ...
    'RadioID', idTX, ...
    'CenterFrequency', fc, ...
    'BasebandSampleRate', SamplingRate, ...
    'Gain', tx_gain);

cleanupObj = onCleanup(@() release(txPluto));

%% ============================================================
%  Start continuous gapless transmission
%% ============================================================

disp("Starting Pluto transmission...");
disp("RF center frequency: " + num2str(fc/1e9) + " GHz");
disp("Baseband tone: " + num2str(tone_freq/1e3) + " kHz");
disp("Expected RF tone: " + num2str((fc + tone_freq)/1e9, '%.9f') + " GHz");

transmitRepeat(txPluto, txWave);

disp("Transmitting continuously with transmitRepeat().");
disp("Press Enter to stop transmission.");
input("");

%% Stop transmission
release(txPluto);
clear cleanupObj;

disp("Transmission stopped.");