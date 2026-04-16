function [accOverall, net] = trainAndEvalClassifier( ...
    training, validation, mapFile, distName, arrayLbl, chanBW, fusionLbl, outDir)

% Input shape and classes
inputSize  = size(training.X, 1:3);                   % [H W C]
classes    = categories(training.Y.classification);
numClasses = numel(classes);

% ----- build a simple CNN (each layer on its own line) -----
layers = [
    imageInputLayer(inputSize, 'Normalization','none','Name','in')
    convolution2dLayer(3,128,'Padding','same','Name','c1')
    batchNormalizationLayer('Name','bn1')
    reluLayer('Name','r1')

    convolution2dLayer(3,128,'Padding','same','Name','c2')
    batchNormalizationLayer('Name','bn2')
    reluLayer('Name','r2')

    averagePooling2dLayer(2,'Stride',2,'Padding','same','Name','p1')

    convolution2dLayer(3,256,'Padding','same','Name','c3')
    batchNormalizationLayer('Name','bn3')
    reluLayer('Name','r3')

    convolution2dLayer(3,256,'Padding','same','Name','c4')
    batchNormalizationLayer('Name','bn4')
    reluLayer('Name','r4')

    averagePooling2dLayer(2,'Stride',2,'Padding','same','Name','p2')

    dropoutLayer(0.35,'Name','drop')

    fullyConnectedLayer(numClasses,'Name','fc')
    softmaxLayer('Name','sm')
    classificationLayer('Name','cls')   % <-- use trainNetwork for classification
];

% ----- training options -----
opts = trainingOptions('adam', ...
    'MiniBatchSize', 64, ...
    'MaxEpochs', 20, ...
    'InitialLearnRate', 1e-3, ...
    'Shuffle','every-epoch', ...
    'ValidationData', {validation.X, validation.Y.classification}, ...
    'Verbose', false);

% ----- train -----
net = trainNetwork(training.X, training.Y.classification, layers, opts);

% ----- predict and accuracy -----
YPred = classify(net, validation.X);
accOverall = mean(YPred == validation.Y.classification);  % fraction 0..1
accPct     = 100*accOverall;

hMap = figure('Name','Location map','Color','w');
ax   = dlPositioningPlotResults(mapFile, validation.Y, YPred, "localization");
if ~ishandle(ax) || ~strcmp(get(ax,'Type'),'axes'); ax = gca; end
title(ax, sprintf('%s — %s | Acc = %.2f%%\n', distName, arrayLbl, accPct));  % <- short!
fnMap = fullfile(outDir, sprintf('map_%s_%s_%s_%s.png', distName, arrayLbl, char(chanBW), fusionLbl));
exportgraphics(hMap, fnMap, 'Resolution', 300);
close(hMap);

% 2) Confusion matrix (COUNTS) with short title
hC = figure('Name','Confusion (counts)','Color','w');
cm = confusionchart(validation.Y.classification, YPred, 'Normalization','absolute');
cm.RowSummary = 'off'; cm.ColumnSummary = 'off';
cm.XLabel = 'Predicted'; cm.YLabel = 'True';
cm.Title  = sprintf('%s — %s | Acc = %.2f%%\n', distName, arrayLbl, accPct); % <- short!
fnCm = fullfile(outDir, sprintf('confusion_%s_%s_%s_%s.png', distName, arrayLbl, char(chanBW), fusionLbl));
exportgraphics(hC, fnCm, 'Resolution', 300);
close(hC);
end
