function plotSummaryCDF(CDFcurves, chanBW, fusionLbl, outDir)
h = figure('Color','w','Name','Positioning summary (CDF)');
hold on;
for k = 1:numel(CDFcurves)
  c = CDFcurves{k};
  if ~isempty(c.x)
    plot(c.x, c.f, 'LineWidth', 2, 'DisplayName', c.label);
  end
end
hold off; grid on;
xlabel('Positioning error (m)'); ylabel('CDF');
title(sprintf('Positioning — %s — %s', char(chanBW), fusionLbl));
legend('Location','southeast','Interpreter','none');
exportgraphics(h, fullfile(outDir, sprintf('summary_positioning_%s_%s.png', ...
             char(chanBW), fusionLbl)), 'Resolution', 300);
close(h);
end
