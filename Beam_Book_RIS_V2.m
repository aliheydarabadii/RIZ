%% Beam book for RIS configs with fixed RX.
clc, clear all, close all

%% Initialization
RIS.f_c = 5.4e9;               % Carrier frequency
c       = physconst('lightspeed');
lambda  = c/RIS.f_c;           % Wavelength
RIS.Ntot= 16;                  % # of rows
RIS.Mtot= 16;                  % # of columns

Nvec    = 0:RIS.Ntot-1;
Mvec    = 0:RIS.Mtot-1;

[N,M]   = meshgrid(Nvec,Mvec);
N       = reshape(N,[],1);
M       = reshape(M,[],1);

% ACTUAL OPEN RIS DIMENSIONS 
RIS.dy  = 20e-3;              % Horizontal spacing  [m]
RIS.dz  = 13e-3;              % Vertical spacing    [m]

% theta should be larger than phi...
tx.theta  = deg2rad(0);    % Incident azimut angle     [-pi/2, pi/2]
tx.phi    = deg2rad(0);    % Incident elevation angle  [-pi/2, pi/2]
rx.theta  = deg2rad(0);   % Exit azimut angle
rx.phi    = deg2rad(-30);     % Exit elevation angle

% Controllare segni azimuth e elevation
tx.r     = 1;                % Transmitter distance in meters
rx.r     = 1;                % Receiver distance in meters

rxy1=1.2;
rxy2=0.95;
rxrange=1.9;



thetaTry = deg2rad(-90:90);  % Theta sweep
phiTry   = deg2rad(-90:90);  % Phi sweep 

% Init degs for beam sweep
theta_sweep = deg2rad(-30:10:30);
phi_sweep   = deg2rad(-50:20:50);

% Init beam pattern matrices an vTrue
BP_cell         = cell(length(phi_sweep), length(theta_sweep));
vTrue_cell      = cell(length(phi_sweep), length(theta_sweep));
Beam_book_cell  = cell(length(phi_sweep), length(theta_sweep));
config_bin_cell = cell(length(phi_sweep), length(theta_sweep));


%% Compute configurataions for 
for i = 1:numel(phi_sweep)
    for j = 1:numel(theta_sweep)

        PHI     = phi_sweep(i);
        THETA   = theta_sweep(j);
        
        % Compute continuous config to quantize
        vTrue   = exp(-1j*2*pi/lambda *( (M*RIS.dy*sin(THETA)*cos(PHI)    + N*RIS.dz*sin(PHI)) ...
                                      +  (M*RIS.dy*sin(rx.theta)*cos(rx.phi) + N*RIS.dz*sin(rx.phi)) ));             % RIS phase shift 

        % Compute quantized config [0,pi] and store it
        vTrue_cell{i,j} = vTrue;
        vTrue_cell{i,j}(angle(vTrue)      >=  -pi/2 & angle(vTrue) < pi/2)    =  1;         % shift of 0
        vTrue_cell{i,j}(not(angle(vTrue)  >=  -pi/2 & angle(vTrue) < pi/2))   = -1;         % shift of pi
        
        p = 1;
        for phi = phiTry
            vTry = exp(-1j*2*pi/lambda *( (M*RIS.dy*sin(thetaTry)*cos(phi) + N*RIS.dz*sin(phi)) ...
                                        + (M*RIS.dy*sin(rx.theta)*cos(rx.phi)    + N*RIS.dz*sin(rx.phi)) ));    % Test phase shifts to match RIS config
        
            % Compute normalized antenna gain
            BP_cell{i,j}(p,:)    = 1/length(Nvec)*1/length(Mvec)*conj(vTrue_cell{i,j}).'*vTry; 
            p = p+1;
        end

        % compute and save Hex config
        vTrue_bin               = vTrue_cell{i,j} == 1;
        vTrue_bin_temp          = reshape(not(vTrue_bin), RIS.Ntot, RIS.Mtot);
        vTrue_bin_temp          = reshape(vTrue_bin_temp,1,[]);
        config_bin_cell{i,j}    = reshape(vTrue_bin_temp, 4,[])';
        Beam_book_cell{i,j}     = string(dec2hex(bin2dec(num2str(config_bin_cell{i,j})))');

    end
end



%% Save Beambook file

% Prepare data for saving
%header = ["Theta (degrees)", "Phi (degrees)", "Beam Configurations"];
data = cell(length(phi_sweep) + 1, length(theta_sweep) + 1);

data(1, 2:end) = num2cell(rad2deg(theta_sweep));
data(2:end, 1) = num2cell(rad2deg(phi_sweep));

% Fill in the Beam configurations
for i = 1:length(phi_sweep)
    for j = 1:length(theta_sweep)
        data{i + 1, j + 1} = Beam_book_cell{i,j};
    end
end
save('beambook_d1_doub1_near.mat','data','phi_sweep','theta_sweep')

% Save to CSV file
writetable(cell2table(data), 'Beam_book_rx_0_d.csv', 'WriteVariableNames', false);

%% Plot BP
figure
tiledlayout(length(phi_sweep), length(theta_sweep));
for ii = 1:size(BP_cell,1)
    for jj = 1:size(BP_cell,2)
    ax = nexttile;   % passa alla prossima tile in orizzontale

    imagesc(rad2deg(thetaTry), rad2deg(phiTry), db(BP_cell{ii,jj}));
    clim([-60 0]);
    axis square;grid on;hold(ax, 'on');
    set(ax, 'YDir', 'normal');
    plot(ax, rad2deg(theta_sweep(jj)), rad2deg(phi_sweep(ii)), 'r*', 'MarkerSize', 6);
    hold(ax, 'off');

    title(ax, sprintf('Beam pattern RIS.  $\\theta_0 = %.1f^\\circ$, $\\phi_0 = %.1f^\\circ$', ...
        rad2deg(theta_sweep(jj)), rad2deg(phi_sweep(ii))), ...
        'Interpreter','latex');
    end
end

figure
tiledlayout(length(phi_sweep), length(theta_sweep));
for ii = 1:size(vTrue_cell,1)
    for jj = 1:size(vTrue_cell,2)
        ax = nexttile; 
  
        imagesc(angle(reshape(vTrue_cell{ii,jj}, RIS.Ntot, RIS.Mtot))')
        axis square, shading flat
        title(ax, sprintf('RIS configuration $\\theta_0 = %.1f^\\circ$, $\\phi_0 = %.1f^\\circ$', ...
        rad2deg(theta_sweep(jj)), rad2deg(phi_sweep(ii))), ...
        'Interpreter','latex');
    end
end