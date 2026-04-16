function savedPath = savePlot(axOrFig, outDir, baseName, suffix)
% savePlot — robust wrapper around exportgraphics
% - axOrFig: axes handle OR figure handle (we’ll detect)
% - outDir:  folder path (created if needed)
% - baseName: short file stem (e.g., 'map_uniform_4x4_CBW40')
% - suffix:   extra text (optional), e.g., 'acc87'
%
% Returns savedPath if success; throws a warning if it can’t save.

    if nargin < 4, suffix = ""; end
    if isstring(outDir) || ischar(outDir)
        outDir = char(outDir);
    end

    % make sure folder exists
    if ~exist(outDir,'dir')
        mkdir(outDir);
    end

    % build a safe filename: letters, digits, _ and -
    sanitize = @(s) regexprep(char(string(s)),'[^A-Za-z0-9_\-]','');
    bn  = sanitize(baseName);
    sfx = sanitize(suffix);

    if isempty(sfx)
        fname = [bn '.png'];
    else
        fname = sprintf('%s_%s.png', bn, sfx);
    end
    savedPath = fullfile(outDir, fname);

    % pick something exportable
    if isa(axOrFig, 'matlab.graphics.axis.Axes')
        target = axOrFig;
        % Empty axes? then export the parent figure if it has content
        if isempty(target.Children)
            fig = ancestor(target,'figure');
            if isempty(fig) || isempty(fig.Children)
                warning('savePlot:emptyAxes', 'Axes is empty. Skipping save: %s', savedPath);
                return
            else
                target = fig;
            end
        end
    elseif isa(axOrFig, 'matlab.ui.Figure')
        target = axOrFig;
        if isempty(target.Children)
            warning('savePlot:emptyFig', 'Figure has no content. Skipping save: %s', savedPath);
            return
        end
    else
        % try current figure as a last resort
        target = gcf;
        if isempty(target.Children)
            warning('savePlot:noHandle', 'No valid handle to save. Skipping: %s', savedPath);
            return
        end
    end

    % do the export
    try
        exportgraphics(target, savedPath, 'Resolution', 300);
        fprintf('Saved: %s\n', savedPath);
    catch ME
        warning('savePlot:exportFail', 'exportgraphics failed: %s\nTarget: %s', ME.message, savedPath);
    end
end
