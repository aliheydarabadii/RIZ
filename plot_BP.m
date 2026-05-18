function [] = plot_BP(thetaTry, phiTry, BP_cell, vTrue_cell, RIS, rx)

    values = ["continuos","[-\pi/2, \pi/2]", "[0, \pi]", "[-\pi, -\pi/2, \pi/2, 0]", "[-3/4\pi, -\pi/4, \pi/4, 3/4\pi]"];

    gg = figure('Units','normalized','Position',[0.4 0.4 0.8 0.8]);
    t = tiledlayout(2,size(BP_cell,2), 'TileSpacing','compact');  

    % First row
    for ii = 1:size(BP_cell,2)
        nexttile, imagesc(rad2deg(thetaTry), rad2deg(phiTry), db(BP_cell{ii})), clim([-60 0]), axis square, shading flat
        hold on, p1 = plot(rad2deg(rx.theta), rad2deg(rx.phi), 'r*', 'MarkerSize', 6); hold off, set(gca, 'YDir', 'normal');
        grid on
        ax = nexttile(ii);
        title(ax,{'Beam pattern RIS ' + values(ii)});
    end    
    
    % Add color bar for the first row
    cb = colorbar; 
    cb.Label.String = 'Beam Pattern (dB)';
   
    % Add common xlabel and ylabel for the first row (row 1)
    ax1 = nexttile(1);                                                          % Access the first tile of the first row
    xlabel(ax1, 'Azimuth angle \theta°', 'FontSize', 14, 'FontWeight', 'bold'); % Apply xlabel to the first axis
    ylabel(ax1, 'Elevation angle \phi°', 'FontSize', 14, 'FontWeight', 'bold'); % Apply ylabel to the first axis
    
    % Second row
    for ii = 1:size(vTrue_cell,2)
        %nexttile, imagesc(flipud(angle(reshape(vTrue_cell{ii}, RIS.Ntot, RIS.Mtot)'))), axis square, shading flat
        nexttile, imagesc(angle(reshape(vTrue_cell{ii}, RIS.Ntot, RIS.Mtot))'), axis square, shading flat
        ax = nexttile(size(BP_cell,2)+ii);
        title(ax,{'RIS precoding for ' + values(ii)});
    end

    % Add common xlabel and ylabel for the second row (row 2)
    ax3 = nexttile(size(BP_cell,2)+1);                                      % Access the first tile of the second row
    xlabel(ax3, 'N', 'FontSize', 14, 'FontWeight', 'bold'); % Apply xlabel to the first axis
    ylabel(ax3, 'M', 'FontSize', 14, 'FontWeight', 'bold'); % Apply ylabel to the first axis
    
    % Common title
    title(t, 'RIS Beam Pattern vs. RIS pre-coding'), t.Title.FontWeight = 'bold'; t.Title.FontSize = 16;
    
    % Add the legend outside the tiled layout
    legend(p1, {'Receiver Position'}, 'FontSize', 14, 'Orientation', 'horizontal', 'location','southoutside');
    
    fig = gcf; % Get current figure handle
    set(findall(fig, '-property', 'FontSize'), 'FontSize', 18); % Set font size

    box on

end

