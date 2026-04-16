function CDF = trainAndEvalRegressor(training, validation, distName, arrayLbl, chanBW, fusionLbl, outDir)
% --- target scaling (train only) ---
muY  = mean(training.Y.regression, 2);
sigY = std(training.Y.regression, 0, 2) + 1e-8;
YtrZ = (training.Y.regression   - muY) ./ sigY;
YvaZ = (validation.Y.regression - muY) ./ sigY;

% --- head ---
layers = [
  imageInputLayer(size(training.X,1:3),'Normalization','none')
  convolution2dLayer(3,128,'Padding','same'), batchNormalizationLayer, reluLayer
  averagePooling2dLayer(2,'Stride',2,'Padding','same')
  convolution2dLayer(3,256,'Padding','same'), batchNormalizationLayer, reluLayer
  averagePooling2dLayer(2,'Stride',2,'Padding','same')
  dropoutLayer(0.3)
  fullyConnectedLayer(3)
];

% robust Huber loss
huber = @(YP,YT) huberLoss(YP,YT,0.5);

opts = trainingOptions("adam", ...
    "MiniBatchSize", 64, "MaxEpochs", 40, "InitialLearnRate", 2e-3, ...
    "LearnRateSchedule","piecewise","LearnRateDropPeriod",15,"LearnRateDropFactor",0.2, ...
    "ValidationData",{validation.X, YvaZ.'}, ...
    "L2Regularization",1e-4, "Shuffle","every-epoch", "Verbose",false);

net = trainnet(training.X, YtrZ.', layers, huber, opts);

% Predict, UNscale
YPredZ = predict(net, validation.X).';
YPred  = YPredZ .* sigY + muY;   % back to meters

trueXY = validation.Y.regression(1:2,:);
predXY = YPred(1:2,:);
err2d  = vecnorm(predXY - trueXY, 2, 1);
err2d  = err2d(isfinite(err2d));

% CDF
[Fr, Xr] = ecdf(err2d.');
CDF = struct('dist',distName,'array',arrayLbl,'cbw',chanBW,'fusion',fusionLbl,'x',Xr,'f',Fr);

% save per-config CDF figure (optional)
h = figure('Color','w');
plot(Xr,Fr,'LineWidth',2); grid on;
xlabel('Distance error (m)'); ylabel('CDF');
title(sprintf('Positioning CDF — %s — %s — %s — %s', distName, arrayLbl, chanBW, fusionLbl));
exportgraphics(h, fullfile(outDir, sprintf('cdf_%s_%s_%s_%s.png', ...
    distName, arrayLbl, chanBW, fusionLbl)), 'Resolution', 300);
close(h);
end
