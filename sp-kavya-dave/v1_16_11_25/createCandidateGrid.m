function candXY = createCandidateGrid(staXY, gridStep)
    % Creates a grid of candidate AP positions covering the STA area.
    margin = 1.0; % 1-meter margin around the STA area
    xMin = min(staXY(:,1)) - margin;
    xMax = max(staXY(:,1)) + margin;
    yMin = min(staXY(:,2)) - margin;
    yMax = max(staXY(:,2)) + margin;
    
    xs = xMin:gridStep:xMax;
    ys = yMin:gridStep:yMax;
    [XX, YY] = meshgrid(xs, ys);
    candXY = [XX(:), YY(:)];
end