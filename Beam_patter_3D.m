%% RIS BEAM PATTERN 3D
clc, clear all, close all

%% Inizialization
RIS.f_c = 5.4e9;              % Carrier frequency
c       = physconst('lightspeed');
lambda  = c/RIS.f_c;           % Wavelength
RIS.Ntot= 16;                  % # of rows
RIS.Mtot= 16;                  % # of columns
%Nvec    = -RIS.Ntot/2:RIS.Ntot/2-1;
%Mvec    = -RIS.Mtot/2:RIS.Mtot/2-1;
Nvec    = 0:RIS.Ntot-1;
Mvec    = 0:RIS.Mtot-1;

[N,M]   = meshgrid(Nvec,Mvec);
N       = reshape(N,[],1);
M       = reshape(M,[],1);
RIS.dy  = lambda/2;            % Horizontal spacing
RIS.dz  = lambda/2;            % Vertical spacing

% ACTUAL OPEN RIS DIMENSIONS 
%RIS.dx  = 20e-3;              % Horizontal spacing [m]
%RIS.dy  = 13e-3;              % Vertical spacing [m]

% theta should be larger than phi...
tx.theta  = deg2rad(21.6);    % Incident azimut angle     [-pi/2, pi/2]
tx.phi    = deg2rad(19.9);    % Incident elevation angle  [-pi/2, pi/2]
rx.theta  = deg2rad(-52.2);   % Exit azimut angle
rx.phi    = deg2rad(0);      % Exit elevation angle

% Controllare segni azimuth e elevation

tx.r     = 1;                % Transmitter distance in meters
rx.r     = 1;                % Receiver distance in meters

thetaTry = deg2rad(-90:90);  % Theta sweep
phiTry   = deg2rad(-90:90);  % Phi sweep 

% Init beam pattern matrices an vTrue
BP_cell     = {};
vTrue_cell  = {};

%% Continuos phase shift beam pattern -> ty use a different geometry
vTrue_cell{1}   = exp(-1j*2*pi/lambda *( (M*RIS.dy*sin(tx.theta)*cos(tx.phi) + N*RIS.dz*sin(tx.phi)) ...
                                      +  (M*RIS.dy*sin(rx.theta)*cos(rx.phi) + N*RIS.dz*sin(rx.phi)) ));             % RIS phase shift 
vTry            = zeros(length(vTrue_cell{1}), length(thetaTry));

p = 1;
for phi = phiTry
    vTry        = exp(-1j*2*pi/lambda *( (M*RIS.dy*sin(tx.theta)*cos(tx.phi) + N*RIS.dz*sin(tx.phi)) ...
                                       + (M*RIS.dy*sin(thetaTry)*cos(phi)    + N*RIS.dz*sin(phi)) ));     % Test phase shifts to match RIS config
    % Conpute normalized antenna gain
    BP_cell{1}(p,:)    = 1/length(Nvec)*1/length(Mvec)*conj(vTrue_cell{1}).'*vTry;                                     
    p = p+1;
end

%% Qauntized beam pattern with two different state [-pi, pi]
vTrue_cell{2} = vTrue_cell{1};
vTrue_cell{2}(angle(vTrue_cell{1}) >= 0)  =  1j;     % shift of  pi/2
vTrue_cell{2}(angle(vTrue_cell{1}) <  0)  = -1j;     % shift of -pi/2

p = 1;
for phi = phiTry
    vTry = exp(-1j*2*pi/lambda *( (M*RIS.dy*sin(tx.theta)*cos(tx.phi) + N*RIS.dz*sin(tx.phi)) ...
                                + (M*RIS.dy*sin(thetaTry)*cos(phi)    + N*RIS.dz*sin(phi)) ));    % Test phase shifts to match RIS config

    % Conpute normalized antenna gain
    BP_cell{2}(p,:) = 1/length(Nvec)*1/length(Mvec)*conj(vTrue_cell{2}).'*vTry; 
    p = p+1;
end

%% Qauntized beam pattern with two different state [0, pi]
vTrue_cell{3} = vTrue_cell{1};
vTrue_cell{3}(angle(vTrue_cell{1}) >=  -pi/2 & angle(vTrue_cell{1}) < pi/2)        =  1;         % shift of 0
vTrue_cell{3}(not(angle(vTrue_cell{1}) >=  -pi/2 & angle(vTrue_cell{1}) < pi/2))   = -1;         % shift of pi

p = 1;
for phi = phiTry
    vTry = exp(-1j*2*pi/lambda *( (M*RIS.dy*sin(tx.theta)*cos(tx.phi) + N*RIS.dz*sin(tx.phi)) ...
                                + (M*RIS.dy*sin(thetaTry)*cos(phi)    + N*RIS.dz*sin(phi)) ));    % Test phase shifts to match RIS config

    % Compute normalized antenna gain
    BP_cell{3}(p,:)    = 1/length(Nvec)*1/length(Mvec)*conj(vTrue_cell{3}).'*vTry; 
    p = p+1;
end

%% Quantized phase shift with 2 bits
vTrue_cell{4} = vTrue_cell{1};
vTrue_cell{4}(angle(vTrue_cell{1}) >= -pi/4 & angle(vTrue_cell{1}) < pi/4)      =   1;          % shift 0
vTrue_cell{4}(angle(vTrue_cell{1}) >=  pi/4 & angle(vTrue_cell{1}) < 3*pi/4)    =   1j;         % shift pi/2
vTrue_cell{4}(angle(vTrue_cell{1}) >= -3*pi/4 & angle(vTrue_cell{1}) < -pi/4)   =  -1j;         % shift -pi/2
vTrue_cell{4}(angle(vTrue_cell{1}) >=  3*pi/4 | angle(vTrue_cell{1}) < -3*pi/4) =  -1;          % shift of pi

p = 1;
for phi = phiTry
    vTry = exp(-1j*2*pi/lambda *( (M*RIS.dy*sin(tx.theta)*cos(tx.phi) + N*RIS.dz*sin(tx.phi)) ...
                                + (M*RIS.dy*sin(thetaTry)*cos(phi)    + N*RIS.dz*sin(phi)) ));    % Test phase shifts to match RIS config

    % Compute normalized antenna gain
    BP_cell{4}(p,:)    = 1/length(Nvec)*1/length(Mvec)*conj(vTrue_cell{4}).'*vTry; 
    p = p+1;
end

%% Quantized phases with 2 bits [pi/4]
vTrue_cell{5} = vTrue_cell{1};
vTrue_cell{5}(angle(vTrue_cell{1}) >=   0   & angle(vTrue_cell{1}) < pi/2)  =   exp(1j*pi/4);          % shift 0
vTrue_cell{5}(angle(vTrue_cell{1}) >=  pi/2 & angle(vTrue_cell{1}) < pi)    =   exp(1j*3*pi/4);         % shift pi/2
vTrue_cell{5}(angle(vTrue_cell{1}) >=  -pi  & angle(vTrue_cell{1}) < -pi/2) =   exp(-1j*3*pi/4);         % shift -pi/2
vTrue_cell{5}(angle(vTrue_cell{1}) >=  -pi/2 & angle(vTrue_cell{1}) < 0)    =   exp(1j*-pi/4);          % shift of pi

p = 1;
for phi = phiTry
    vTry = exp(-1j*2*pi/lambda *( (M*RIS.dy*sin(tx.theta)*cos(tx.phi) + N*RIS.dz*sin(tx.phi)) ...
                                + (M*RIS.dy*sin(thetaTry)*cos(phi)    + N*RIS.dz*sin(phi)) ));     % Test phase shifts to match RIS config

    % Compute normalized antenna gain
    BP_cell{5}(p,:)    = 1/length(Nvec)*1/length(Mvec)*conj(vTrue_cell{5}).'*vTry; 
    p = p+1;
end

clear p

%% Plot Beam patterns
%vTrue_cell{1} =  deg2rad(ph_compensated);
% BP_cell(2)      = [];
% vTrue_cell(2)   = [];
% BP_cell(4)      = [];
% vTrue_cell(4)   = [];

plot_BP(thetaTry, phiTry, BP_cell, vTrue_cell, RIS, rx)

% figure
profile = unwrap(unwrap(angle(reshape(vTrue_cell{1}, RIS.Ntot, RIS.Mtot)')),[],2);
% %profile = unwrap(unwrap(vTrue_cell{1}),[],2);
% surf(Mvec, Nvec, profile'), axis square
% xlabel('Z'); ylabel('Y'); zlabel('X');
% 
% %writematrix()

[X, Y] = meshgrid(Mvec, Nvec);     % Example
Z = profile;

% Rotate 90° around Y-axis
X_new = Z;
Y_new = Y;
Z_new = X;

% Plot rotated surface
figure
surf(X_new, Y_new, Z_new);
xlabel('X'); ylabel('Y'); zlabel('Z');
axis square

%% Extract the configuration of digital RIS (0 pi)
vTrue_bin   = vTrue_cell{3} == 1;
%config_bin  = reshape(vTrue_bin, 4,[])';
vTrue_bin_temp = reshape(not(vTrue_bin), 16,16);
%vTrue_bin_temp = flip(vTrue_bin_temp,2);
vTrue_bin_temp = reshape(vTrue_bin_temp,1,[]);
config_bin  = reshape(vTrue_bin_temp, 4,[])';
config_hex  = string(dec2hex(bin2dec(num2str(config_bin)))');
writematrix("0x" + config_hex, 'config.txt', 'FileType', 'text');
save("config.mat", "config_hex");

%% Extract config with 2 bits (0, pi/2,-pi/2 -pi)
%vTrue_bin2  = [real(vTrue_cell{4}) > 0 | imag(vTrue_cell{4}) > 0 imag(vTrue_cell{4}) ~= 0];
%config_bin2 = reshape(vTrue_bin2',4,[])';

%config_hex2  = string(dec2hex(bin2dec(num2str(config_bin2)))');

%writematrix("0x" + config_hex2, 'config2.txt', 'FileType', 'text');
%save("config2.mat", "config_hex2");

%% RIS Spherical beam pattern
[P,T] = meshgrid(thetaTry-pi,phiTry-pi/2);
T = reshape(T,[],1);
P = reshape(P,[],1);

% Limit all beam pattern to -30 dB and reshape
BP_resh_cell = cell(1,4);

for ii = (1:length(BP_cell))
    BP_resh_cell{ii} = db(reshape(BP_cell{ii},[],1));
    BP_resh_cell{ii} = clip(BP_resh_cell{ii}, -30,0);
end

%% Plot RIS with 3D BP
gg = figure('Units', 'normalized', 'Position', [0.2 0.2 0.6 0.6]);

% Plot patternCustom 
bp = patternCustom(BP_resh_cell{1}, rad2deg(T), rad2deg(P));
colormap('parula')
cb = colorbar;
cb.Label.String = 'Beam Pattern 3D (dB)';
hold on;

% % Plot the imagesc on the same axes
% img = imagesc(Nvec/RIS.Ntot, Mvec/RIS.Mtot, rescale(angle(reshape(flip(vTrue_cell{1}), RIS.Ntot, RIS.Mtot)'),-30,0));
% 
% % Finalize plot
% hold off;
% title('BP discrete [0, \pi]'),
% set(findall(gg, '-property', 'FontSize'), 'FontSize', 16);  % Set font size for the entire figure
% box on

%% Compute received power in a sample scenario.

%init 
tx.Pt= 1;           % Transmit power (Watts)
tx.G = 10^(17/10);  % Transmitter antenna gain (linear)
tx.r = 10;          % Transmitter distance (meters)
rx.G = 10^(17/10);  % Receiver antenna gain (linear)
rx.r = 100;         % Receiver distance (meters)

% init signal cell
sig_cell    = {};
Pr_cell     = {}; 

scenario.npoints = 150;     % # of sample points in space

scenario.xmin =  0;         % Minimum x distance (m)
scenario.xmax =  20;        % Maximum x distance (m)
scenario.ymin = -20;        % Minimum y distance (m)
scenario.ymax =  20;        % Maximum y distance (m)
scenario.zmin = -20;        % Minimum z distance (m)
scenario.zmax =  20;        % Maximum z distance (m)

% Generate scenario poins
scenario.xs = linspace(scenario.xmin, scenario.xmax, scenario.npoints);
scenario.ys = linspace(scenario.ymin, scenario.ymax, scenario.npoints);
scenario.zs = linspace(scenario.zmin, scenario.zmax, scenario.npoints);

% Coordinates of tx and rx
tx.coords = tx.r*[cos(tx.theta)*cos(tx.phi), cos(tx.phi)*sin(tx.theta), sin(tx.phi)];
rx.coords = rx.r*[cos(rx.theta)*cos(rx.phi), cos(rx.phi)*sin(rx.theta), sin(rx.phi)];

% Compute received power for each point in the scenario
xt = tx.coords(1);
yt = tx.coords(2);
zt = tx.coords(3);

% Coordinates of receiver points in the scenario
[xr, yr] = meshgrid(scenario.xs,scenario.ys);

xr = reshape(xr,[],1);
yr = reshape(yr,[],1);
zr = zeros(length(xr),1);

% Disntance transmitter-RIS RIS-receiver
d1 = sqrt(xt.^2 + yt.^2 + zt.^2);
d2 = sqrt(xr.^2 + yr.^2 + zr.^2);

% Coordinates of RIS elements
xnm = 0;
ynm = M*RIS.dy;
znm = N*RIS.dz;

% Distance tx-RISelement RISelement-rx
Rtx = sqrt( (xt - xnm).^2 + (yt - ynm).^2 + (zt - znm).^2); 
Rrx = sqrt( (xnm - xr').^2 + (ynm - yr').^2 + (znm - zr').^2); 

% Distance RISelement-center of RIS
dnm = sqrt(xnm.^2 + ynm.^2 + znm.^2); 

% Attenuation
Ftx     = ( ( d1.^2 + Rtx.^2 - dnm.^2 )./(2*d1*Rtx) ).^(tx.G/2 - 1); 
Frx     = ( ( d2.^2' + Rrx.^2 - dnm.^2 )./(2*d2'.*Rrx) ).^(rx.G/2 - 1); 
Fuct    = (xt./Rtx); 
Fucr    = (xr'./Rrx);
Fcomb   = (Ftx.*Fuct).*(Fucr.*Frx); 

for ii = 1:size(vTrue_cell,2)
    sig_cell{ii} = sqrt(Fcomb).*vTrue_cell{ii}.*exp(-1j*2*pi/lambda*((Rtx + Rrx)))./(Rtx.*Rrx); 
    sig_cell{ii} = sum(sig_cell{ii},1); 

    Pr_cell{1,ii}  = ((tx.Pt*tx.G*rx.G*RIS.dy*RIS.dz*lambda^2*4)/(RIS.Mtot*RIS.Ntot*pi^3)).*abs(sig_cell{ii}).^2; 
    Pr_cell{2,ii}  = reshape(db(Pr_cell{1,ii}), scenario.npoints, scenario.npoints);
end

%% Plot received power 
plot_Pr(scenario, Pr_cell, tx, rx)

% %% Set specifi config
% %set_config(RIS,tx,rx,scenario);