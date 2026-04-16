function plotSummaryBars(T, chanBW, fusionLbl, outDir)
% Split "Config" like "4x1-uniform" into two columns
parts = split(T.Config,'-');
arrayLbl = parts(:,1); distLbl = parts(:,2);
sz = unique(arrayLbl,'stable');
ds = {'uniform','random'};

accMat = NaN(numel(sz), numel(ds));  % rows: arrays, cols: dists
for i=1:numel(sz)
  for j=1:numel(ds)
    k = find(strcmp(arrayLbl,sz{i}) & strcmp(distLbl,ds{j}));
    if ~isempty(k), accMat(i,j) = T.AccuracyPct(k(1)); end
  end
end

h = figure('Color','w'); hold on;
bh = bar(accMat,'grouped'); grid on;
xticklabels(sz); xlabel('Antenna size'); ylabel('Accuracy (%)');
legend(ds,'Location','southoutside','Orientation','horizontal');
title(sprintf('Localization accuracy — %s — %s', chanBW, fusionLbl));
for i=1:numel(bh)
  xOff = bh(i).XEndPoints; yOff = bh(i).YEndPoints;
  for k=1:numel(xOff)
    if ~isnan(yOff(k)), text(xOff(k),yOff(k)+1,sprintf('%.1f',yOff(k)), ...
          'HorizontalAlignment','center','FontSize',9); end
  end
end
exportgraphics(h, fullfile(outDir, sprintf('summary_localization_bar_%s_%s.png', chanBW, fusionLbl)), 'Resolution', 300);
close(h);
end

function plotSummaryCDF(CDFcurves, chanBW, fusionLbl, outDir)
colors = lines(numel(CDFcurves));
h = figure('Color','w'); hold on;
for i=1:numel(CDFcurves)
  c = CDFcurves{i};
  if isempty(c.x), continue; end
  plot(c.x, c.f, 'LineWidth', 2, 'DisplayName', ...
    sprintf('%s — %s', c.dist, c.array));
end
grid on; xlabel('Distance error (m)'); ylabel('CDF');
title(sprintf('Final CDF — Positioning error (all configs) — %s — %s', chanBW, fusionLbl));
legend('Location','southoutside','NumColumns',2);
exportgraphics(h, fullfile(outDir, sprintf('summary_positioning_cdf_%s_%s.png', chanBW, fusionLbl)), 'Resolution', 300);
close(h);
end

function out = ternary(cond, a, b)
if cond, out = a; else, out = b; end
end
