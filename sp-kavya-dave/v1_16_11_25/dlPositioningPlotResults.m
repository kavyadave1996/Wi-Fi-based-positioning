function metric = dlPositioningPlotResults(mapFileName, labels, YPred, task)
%dlPositioningPlotResults Visualize indoor location estimation predictions
%   METRIC = dlPositioningPlotResults(MAPFILENAME, LABELS, YPRED, TASK)
%   visualises results of location estimation in a 3D environment modeled
%   in an stl file, MAPFILENAME. Plot the STAs true position according to
%   LABELS and display the predicted location, YPRED. These will be a
%   position vector of length 3 or a categorical location label depending
%   on the value of TASK.
%
%   METRIC is the mean position error when TASK = "positioning" and the
%   mean accuracy when TASK = "localization".

%   Copyright 2020 The MathWorks, Inc. 


YTrue = labels.classification;
locs = labels.regression;
if ~isa(mapFileName, 'triangulation')
    tri = stlread(mapFileName);
else
    tri = map;
end
figure
trisurf(tri, ...
    'FaceAlpha', 0.3, ...
    'FaceColor', [.5, .5, .5], ...
    'EdgeColor', 'none');
view(60, 30);
hold on; axis equal; grid off;
xlabel('x'); ylabel('y'); zlabel('z');
view([84.75 56.38])
% Plot edges
fe = featureEdges(tri,pi/20);
numEdges = size(fe, 1);
pts = tri.Points;
a = pts(fe(:,1),:); 
b = pts(fe(:,2),:); 
fePts = cat(1, reshape(a, 1, numEdges, 3), ...
    reshape(b, 1, numEdges, 3), nan(1, numEdges, 3));
fePts = reshape(fePts, [], 3);
plot3(fePts(:, 1), fePts(:, 2), fePts(:, 3), 'k', 'LineWidth', .5); 

if task =="positioning"
    positionError = plotRegression(locs, YPred);
    metric = positionError;
else
    classAccuracy = plotClassification(YTrue, YPred, locs);
    metric = classAccuracy;
end

end



