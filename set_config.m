function [config] = set_config(RIS, tx, rx, scenario)
%SET_CONFIG returns the RIS configuration and plots it alongside power distribution and beam
%patter of a specific RIS given a specific scenario.
%   [config] = set_config(RIS, tx, rx, scenario)
%   RIS is a structure that contains: 
%   f_c = working frequency,
%   N,M = # of columns, # of rows,
%   dx,dy = vertical and horizontal disance between RIS elements.
%   tx and rx are structures containing:
%   G = gain,
%   Pt (only tx) = transmitted power,
%   theta, phi = azimuth and elevation angle,
%   r = distance,
%   coords = cpprdinates.
%   scenario is a stucture containing:
%   npoints = # of points in each dimension of the scenario,
%   xmin, xmax = maximum horizontal dimensions,
%   ymin, ymax = maximum vertical dimensions,
%   zmin, zmax = maximum depth dimensions.
%
%   config is the 1 bit RIS configuration. 

%% Set config and plot the impulse response of the RIS wrt. phi at a reference distance in the far field (8.3m)

%init
c       = physconst('lightspeed');
f_c     = RIS.f_c;
lambda  = c/f_c;
Mtot    = RIS.Mtot;
Ntot    = RIS.Ntot;
Mvec    = -Mtot/2:Mtot/2-1; 
Nvec    = -Ntot/2:Ntot/2-1;
[N,M]   = meshgrid(Nvec,Mvec);
N       = reshape(N,[],1);
M       = reshape(M,[],1);
dx      = RIS.dx;
dy      = RIS.dy;

theta_i = tx.theta;
theta_o = rx.theta;
phi_i   = tx.phi;
phi_o   = rx.phi;

npoints = scenario.npoints;

thetaTry= deg2rad(-90:1:90);   % Theta sweep
phiTry  = deg2rad(-90:1:90);   % Phi sweep 

% Set the configuration as an x16 input from the user
config = input('Select configuration in 0x: ', 's');  % 's' ensures string input

% Check if input is exactly 64 characters long
if length(config) ~= 64
    error('Input must be exactly 64 characters long.');
end

% Ensure the input is a valid hexadecimal string
if isempty(regexp(config, '^[0-9A-Fa-f]{64}$', 'once'))
    error('Input must be a valid 64-character hexadecimal string.');
end

% Manually convert hex to binary vector (256 bits for 64 hex characters)
configBinary = [];
for i = 1:length(config)
    % Convert each hex character to its 4-bit binary equivalent
    binStr = dec2bin(hex2dec(config(i)), 4);  % Hex to decimal, then to binary
    configBinary = [configBinary, binStr];  % Concatenate binary strings
end

% Convert to a logical vector (1 for '1', 0 for '0')
configBinary = configBinary == '1';  % Convert characters to logical values

% Reshape the binary vector into a 16x16 matrix
config = reshape(configBinary, 16, 16);  % Transpose to match desired shape

% % Random configuration -> only for testing
% config = randi([0,1], Mtot*Ntot,1);
% config = reshape(config, Ntot, Mtot);
% 
% clear PrdB_rnd;

% Set phase shift as a 1bit variable [0, pi]
vTrue = zeros(Ntot,Mtot);
vTrue(config == 1) = 1;
vTrue(config == 0) =-1;
vTrue = reshape(vTrue,[],1);

%% Compute beam pattern
%vTrue   = exp(-1j*2*pi/lambda *( (M*dy*sin(theta_i)*cos(phi_i) + N*dx*sin(phi_i)) ...
%                               - (M*dy*sin(theta_o)*cos(phi_o) + N*dx*sin(phi_o)) ));                 % RIS phase shift 

BP     = zeros(length(thetaTry), length(phiTry));

p = 1;
for phi = phiTry
    vTry       = exp(-1j*2*pi/lambda *( (M*dy*sin(theta_i)*cos(phi_i) + N*dx*sin(phi_i)) ...
                                      - (M*dy*sin(thetaTry)*cos(phi)  + N*dx*sin(phi)) ));    % Test phase shifts to match RIS config
    BP(p,:)    = 1/length(Nvec)*1/length(Mvec)*conj(vTrue).'*vTry; 
    p = p+1;
end

%% Sample received power over plane defined by zind, xind
xt = tx.coords(1);
yt = tx.coords(2);
zt = tx.coords(3);

[xr, yr] = meshgrid(scenario.xs,scenario.ys);

xr = reshape(xr,[],1);
yr = reshape(yr,[],1);
zr = zeros(length(xr),1);

d1 = sqrt(xt.^2 + yt.^2 + zt.^2);
d2 = sqrt(xr.^2 + yr.^2 + zr.^2);

xnm = 0;
ynm = M*dx;
znm = N*dy;

Rtx = sqrt( (xt - xnm).^2 + (yt - ynm).^2 + (zt - znm).^2); 
Rrx = sqrt( (xnm - xr').^2 + (ynm - yr').^2 + (znm - zr').^2); 

dnm = sqrt(xnm.^2 + ynm.^2 + znm.^2); 

Ftx     = ( ( d1.^2 + Rtx.^2 - dnm.^2 )./(2*d1*Rtx) ).^(tx.G/2 - 1); 
Frx     = ( ( d2.^2' + Rrx.^2 - dnm.^2 )./(2*d2'.*Rrx) ).^(rx.G/2 - 1); 
Fuct    = (xt./Rtx); 
Fucr    = (xr'./Rrx);
Fcomb   = (Ftx.*Fuct).*(Fucr.*Frx); 

sig = sqrt(Fcomb).*vTrue.*exp(-1j*2*pi/lambda*((Rtx + Rrx)))./(Rtx.*Rrx); 
sig = sum(sig,1); 

Pr          = ((tx.Pt*tx.G*rx.G*dx*dy*lambda^2)/(64*pi^3)).*abs(sig).^2; 
PrdB_hoz    = reshape(db(Pr), npoints, npoints);

%% Plot configuration and impulse response
gf = figure;  
gf.Position = [100,100,1200,600];

% Create a 1x3 tiled layout
tiledlayout(1, 3, 'TileSpacing', 'compact');

% Plot configuration (First Tile)
ax1 = nexttile;  % Get the axes handle for the first tile
imagesc(angle(reshape(vTrue, Ntot, Mtot))');
title('Continuous RIS configuration'), axis square, shading flat
colormap(ax1, 'parula'); % Set colormap for the first plot
hold on
qw{1} = plot(nan, 'rs','MarkerFaceColor','blue', 'MarkerSize', 15);
qw{2} = plot(nan, 'bs','MarkerFaceColor','yellow', 'MarkerSize', 15);
legend([qw{:}], {'V_{bias} = V^B_1','V_{bias} = V^B_2'}, 'orientation', 'horizontal', 'Box', 'off', 'location', 'southoutside')
title('RIS configuration', 'FontSize', 12), xlabel('M'), ylabel('N');
hold off

% Plot beam pattern (Second Tile)
ax2 = nexttile;  % Get the axes handle for the second tile
imagesc(rad2deg(phiTry), rad2deg(thetaTry), db(BP)), clim([-70 0]), axis square, shading flat
colormap(ax2, 'parula'); % Set colormap for the second plot
cb = colorbar; % Add colorbar for the second plot
cb.Label.String = 'Beam Pattern (dB)';
hold on
p1 = plot(rad2deg(theta_o), rad2deg(phi_o), 'r.', 'MarkerSize', 15); 
hold off
set(gca, 'YDir', 'normal');
grid on
title('Beam Pattern RIS'), xlabel('Azimuth angle \theta°'), ylabel('Elevation angle \phi°')
legend(p1, {'Receiver Position'}, 'Orientation', 'horizontal', 'Box', 'off', 'location','southoutside');

% Plot power distribution on zx plane (Third Tile)
ax3 = nexttile;  % Get the axes handle for the third tile
surf(scenario.xs, scenario.ys, PrdB_hoz);
title('Received power over xy plane'), xlabel('x[m]'), ylabel('y[m]')
view(2), shading flat
colormap(ax3, 'jet'); % Set colormap for the third plot
cb = colorbar; % Add colorbar for the third plot
cb.Label.String = 'Received power (dB)';
xlim([scenario.xmin, scenario.xmax]), ylim([scenario.ymin, scenario.ymax]);
hold on;
plot(8.3*cosd((-90:3:90)), 8.3*sind((-90:3:90)), '.', 'MarkerSize', 3, 'Color', 'blue');
l1 = plot((0:1:40)*cos(theta_o), (0:1:40)*sin(-theta_o), '--', 'LineWidth', 2, 'Color', 'blue');
l2 = plot((0:1:40)*cos(theta_i), (0:1:40)*sin(-theta_i), '--', 'LineWidth', 2, 'Color', 'red');
legend([l1, l2], {'\theta_o', '\theta_i'}, 'Orientation', 'horizontal', 'Box', 'off', 'Location','southoutside')
pbaspect([1 2 1]);

% Set the font size for all text in the figure
fig = gcf;  % Get current figure handle
set(findall(fig, '-property', 'FontSize'), 'FontSize', 14);  % Set font size for the entire figure

box on

%% PLot 3D Beam pattern
[T,P] = meshgrid(thetaTry,phiTry);
T = reshape(T,[],1);
P = reshape(P,[],1);

BP_resh = db(reshape(BP,[],1));
BP_resh = clip(BP_resh, -30,0);

gg = figure('Units','normalized','Position',[0.2 0.2 0.6 0.6]);

bp = patternCustom(BP_resh, rad2deg(T), rad2deg(P));
colormap('parula')
cb = colorbar;
cb.Label.String = 'Beam Pattern 3D (dB)';
hold on;

% Plot the imagesc on the same axes
img = imagesc(Nvec/RIS.Ntot, Mvec/RIS.Mtot, flip(rescale(angle(reshape(vTrue, RIS.Ntot, RIS.Mtot))',-30,0)));

% Finalize
hold off;
title('BP discrete [-\pi/2, \pi/2]'),
set(findall(gg, '-property', 'FontSize'), 'FontSize', 16);  % Set font size for the entire figure

end

