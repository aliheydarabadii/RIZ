function [] = plot_Pr(scenario, Pr_cell, tx, rx)
%PLOT_PW it plots the received power of a given scenario.
%   Scenario is a struct containing all the minimum and mazimum dimension
%   and the number of points.
%   Received_power is the values or the received power for each point in the
%   scenario.
values = ["continuos","[-\pi/2, \pi/2]", "[0, \pi]", "[-\pi, -\pi/2, \pi/2, 0]", "[-3/4\pi, -\pi/4, \pi/4, 3/4\pi]"];

gg = figure('Units','normalized','Position',[0.4 0.4 0.8 0.8]);
t = tiledlayout(1,size(Pr_cell,2), 'TileSpacing','compact');  % Tiled layout for 4 plots

for ii = 1:size(Pr_cell,2)
    nexttile;
    surf(scenario.xs, scenario.ys, Pr_cell{2,ii});
    ax = nexttile(ii);
    title(ax,{'RIS ' + values(ii)});
    view(2), shading flat, colormap jet, clim([-260,-80])
    xlim([scenario.xmin, scenario.xmax]), ylim([scenario.ymin, scenario.ymax]);
    hold on;
    plot(8.3*cosd((-90:3:90)), 8.3*sind((-90:3:90)), '.', 'MarkerSize', 3, 'Color', 'blue');
    l1 = plot((0:1:40)*cos(rx.theta), (0:1:40)*sin(rx.theta), '--', 'LineWidth', 2, 'Color', 'blue');
    l2 = plot((0:1:40)*cos(tx.theta), (0:1:40)*sin(tx.theta), '--', 'LineWidth', 2, 'Color', 'red');
    pbaspect([1 2 1]);
end    

% Common Title, X-label, and Y-label for the entire figure
title(t, 'Received Power on the xy plane');
t.Title.FontWeight = 'bold';  % Set title to bold
t.Title.FontSize = 16;        % Set font size

% Set common x and y labels
xlabel(t, 'x [m]');
ylabel(t, 'y [m]');

% Legend for the plots (added once to avoid repetition)
lgd = legend([l1, l2], {'\theta_o', '\theta_i'}, 'Orientation', 'horizontal');
lgd.Layout.Tile = 'south';

% Colorbar
cb = colorbar; 
cb.Label.String = 'Received power (dB)';

% Set the font size for all text in the figure
fig = gcf;  % Get current figure handle
set(findall(fig, '-property', 'FontSize'), 'FontSize', 18);  % Set font size for the entire figure

% Box around the figure
box on;

end

