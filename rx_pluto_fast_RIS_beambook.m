clc,  clear all, close all

%% Initialization of the Pluto
% SamplingRate=5e5;
% fc=5401e6;

SamplingRate=1e6;
fc=5000e6;

%Finding pluto radio connected
radios=findPlutoRadio;
disp(radios)

%idRX='sn:1044730a1997000714001c00f7547c7e79'; % Always check the pluto serial #
idRX='usb:0' % if using a single puto


%Declaring RX object
rxPluto = sdrrx('Pluto','RadioID',...
    idRX,'CenterFrequency',fc,...
    'GainSource','Manual',...
    'Gain',40,...
    'OutputDataType','int16',...
    'BasebandSampleRate',SamplingRate, ...
    'SamplesPerFrame', 2^13); 

%% Load RIS Beam Book
%input_path = "C:\Users\fedem\OneDrive - Politecnico di Milano\PhD\RIS\Opne_RIS_Git\RIS_config\Beam_book.csv";
%input_path = "../RIS_config/Beam_book_1.csv";
input_path = "../RIS_config/Beam_book_rx_0_d.csv";

beam_book = readtable(input_path);

theta_sweep = str2double(table2array(beam_book(1,2:end))); % need to frce the fist line to be a number
phi_sweep   = table2array(beam_book(2:end,1));

beam_book(1,:) = [];
beam_book(:,1) = [];

beam_book   = table2array(beam_book);

%% Perfom continuous acquisistion of the pluto RSSI

%IRShandle = serialport("/dev/tty.usbserial-D3AD02VH",115200); %use for mac, check the serial port
IRShandle = serialport("COM3",115200); % Use for PC, check the COM port

count = 1;

num_iter = 3;

RSSI_image  = zeros(length(phi_sweep), length(theta_sweep), num_iter);
rxPluto();
disp("Begin RSSI beam measures")

input("Press Enter to continue...")
rxPluto();
rxPluto();


while count <= num_iter
    tic
    for i = 1:length(phi_sweep)
        for j = 1:length(theta_sweep)
            
            theta   = theta_sweep(j);
            phi     = phi_sweep(i);
    
            % load config onto the RIS
            writeline(IRShandle,"!0x" + beam_book(i,j))

            pause(2e-3);

            % Compute RSSI
            rxPluto();
            
            rxWave = rxPluto();   
             
            % Convert only if you really need single
            rxWave = single(rxWave)/2^11;
            
            % Compute RSSI
            RSSI = pow2db(mean(abs(rxWave)));

            RSSI_image(i,j,count) = RSSI; 
    
            % print message on screen with RSSI value
            %msg = "RSSI: " + num2str(RSSI) + " dB";
            %disp(msg)
            toc
        end
    end
    toc
    %% Plot RSSI Map

    figure
    H=imagesc(theta_sweep, phi_sweep, flipud(RSSI_image(:,:,count)));
    colormap("cool");
    colorbar;
    xticks(theta_sweep);           
    yticks(phi_sweep); 
    ylabel('\phi_o (degrees)');
    xlabel('\theta_o (degrees)');
    title(['RSSI Heatmap for measure #', num2str(count)]);
    axis xy;
    axis equal tight;

    count = count+1;

end
toc

% Average RSSI in linear
RSSI_image = db2pow(RSSI_image);
RSSI_image_avg = mean(RSSI_image,3);
RSSI_image_avg = pow2db(RSSI_image_avg);


%% Plot AVG RSSI
figure
imagesc(theta_sweep, phi_sweep, flipud(RSSI_image_avg));
colormap("cool");
cb = colorbar;
%clim([-22,-12]);
cb.Label.String = 'RSSI (dB)';

xticks(theta_sweep);           
yticks(phi_sweep); 
ylabel('$\varphi_o^\circ$ (deg.)', 'Interpreter','latex');
xlabel('$\theta_o^\circ$ (deg.)', 'Interpreter','latex');
%title(' RSSI Heatmap', 'Interpreter','latex');
axis xy;
axis equal tight;

fig = gcf; % Get current figure handle
set(findall(fig, '-property', 'FontSize'), 'FontSize', 24); % Set font size

%% Save data

%save('Alario_8_1/RSSI_data_Alario_8_1_baseline.mat', 'RSSI_image', 'RSSI_image_avg', 'theta_sweep', 'phi_sweep', 'beam_book');



                if dataok == 1   %only the first time we initialize the plot

                    H = imagesc(powermap,'Interpolation', 'bilinear');
                    set (gca, 'YTick', [1,2,3], 'XTick',[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21]);
                    set(gcf, 'Units', 'Normalized', 'OuterPosition', [0.1, 0.2, 0.8, 0.5]);
                    colormap cool;
                    caption1 = sprintf('RX Read Number %d out of %d', i, N_reads);
                    caption2 = sprintf('TX Beam Number %d out of %d', bit_beam, N_beams);
                    colorbar;
                    caxis([300 2400]);
                    [t,sub] = title(caption1, caption2);
                    t.FontSize = 14;
                    t.Color = 'blue';
                    sub.FontSize = 10;
                    sub.Color = 'red';
                    sub.FontAngle = 'italic';
                    pause(0.018);
                else %we update the plot
                    set(H, 'CData', fliplr(powermap));
                    caption1 = sprintf('RX Read Number %d out of %d', i, N_reads);
                    caption2 = sprintf('TX Beam Number %d out of %d', bit_beam, N_beams);
                    [t,sub] = title(caption1, caption2);
                    pause(0.018);
                end










