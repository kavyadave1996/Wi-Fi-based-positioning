clear; close all; clc;

rng('shuffle');

antennaSizes = [4, 2, 1];
chanBW = "CBW40";
distribution = {"uniform", "random"};

staSeparations = [0.25, 0.5, 0.7];  % STA spacing in meters

% === NEW: Material and Fusion Configuration ===
materials = {'concrete', 'wood', 'metal', 'glass', 'plasterboard'};  % 5 materials

fusionStrategies = {
    % 'CIR_only',           % No fusion (baseline)
    % 'CIR_RSSI',           % CIR + RSSI concatenation
    %'CIR_AoA',            % CIR + Angle of Arrival
    % 'CIR_ToF',            % CIR + Time of Flight
    'CIR_RSSI_AoA_ToF'    % Full multimodal fusion
    };  % 5 fusion strategies (adjust as needed)
mapFile = "layout.stl";

% --- results folder (create once at start of script) ---
outDir = "results_sweep";         % use string or char, consistent across script
if ~exist(outDir, 'dir')
    mkdir(outDir);
end


allAccuracy = struct();
allPositionError = struct();

for distIdx = 1:numel(distribution)
    distName = distribution{distIdx};
    fprintf("\n========== DISTRIBUTION: %s ==========\n", distName);
    
    % === LOOP 1: STA SEPARATION ===
    for sepIdx = 1:numel(staSeparations)
        staSep = staSeparations(sepIdx);
        fprintf("\n  --- STA Separation: %.1f m ---\n", staSep);
        
        % === LOOP 2: MATERIAL ===
        for matIdx = 1:numel(materials)
            materialName = materials{matIdx};
            fprintf("\n    --- Material: %s ---\n", materialName);
            
            % === LOOP 3: FUSION STRATEGY ===
            for fusIdx = 1:numel(fusionStrategies)
                fusionType = fusionStrategies{fusIdx};
                fprintf("\n      --- Fusion: %s ---\n", fusionType);
                
                % Initialize result storage for this configuration
                localizationCDF = cell(1, numel(antennaSizes));
                positioningCDF = cell(1, numel(antennaSizes));
                accuracyArray = zeros(1, numel(antennaSizes));
                meanDistErrArray = zeros(1, numel(antennaSizes));
                
                % === LOOP 4: ANTENNA SIZE ===
                for antIdx = 1:numel(antennaSizes)
                    txArraySize = [antennaSizes(antIdx), 1];
                    rxArraySize = [antennaSizes(antIdx), 1];
                    
                    fprintf("\n[Antenna: %dx1] Processing...\n", antennaSizes(antIdx));
                        % ---- SKIP IF THIS CONFIG WAS ALREADY RUN (confusion image exists) ----
                    cmPattern = sprintf('confusion_%s_sep%.1f_%s_%s_%dx1_%s_acc*.png', ...
                        distName, staSep, materialName, fusionType, ...
                        antennaSizes(antIdx), char(chanBW));
                
                    if ~isempty(dir(fullfile(outDir, cmPattern)))
                        fprintf('>>> Skipping already-done config: Dist=%s | Sep=%.1f | Mat=%s | Fusion=%s | Ant=%dx1\n', ...
                            distName, staSep, materialName, fusionType, antennaSizes(antIdx));
                        continue;   % go to next antenna size (or next fusion when loop finishes)
                    end
                    % ----------------------------------------------------------------------

     
                % Create environment based on distribution and STA separation
                if distName == "uniform"
                    % Use current STA separation from loop
                    [APs, STAs] = dlPositioningCreateEnvironment(txArraySize, rxArraySize, staSep, "uniform");
                    
                    % Calculate expected number of STAs
                    roomX = [0.1, 4.9]; roomY = [0.1, 7.9]; roomZ = [0.8, 1.8];
                    expectedSTAs = ceil(diff(roomX)/staSep) * ceil(diff(roomY)/staSep) * ceil(diff(roomZ)/staSep);
                    fprintf("          Expected STAs (uniform): %d\n", expectedSTAs);
                    
                else
                    % For random distribution, scale number based on separation
                    % Denser separation → more random STAs
                    baseNumSTAs = 500;
                    scaleFactor = (0.5 / staSep)^2;  % Quadratic scaling
                    numSTAs = round(baseNumSTAs * scaleFactor);
                    numSTAs = min(numSTAs, 1000);  % Cap at 5000 for computational reasons
                    
                    [APs, STAs] = dlPositioningCreateEnvironment(txArraySize, rxArraySize, numSTAs, "random");
                    fprintf("          Random STAs generated: %d\n", numSTAs);
                end
                
                fprintf("          Actual STAs created: %d\n", numel(STAs));

                %% ------------------- GA-Based AP Placement -------------------
                % Ensure STA coordinates are defined
                N = numel(STAs);
                staXY = zeros(N, 2);
                for k = 1:N
                    p = STAs(k).AntennaPosition;
                    staXY(k, :) = double(p(1:2)).';
                end

                % Candidate AP positions
                margin = 0.5; gridStep = 1.5;
                area = [min(staXY(:,1))-margin, max(staXY(:,1))+margin, ...
                    min(staXY(:,2))-margin, max(staXY(:,2))+margin];
                xs = area(1):gridStep:area(2);
                ys = area(3):gridStep:area(4);
                [XX, YY] = meshgrid(xs, ys);
                candXY = [XX(:), YY(:)];
                Nc = size(candXY, 1);

                % ---------- Coverage target & GA weighting (edit these to demand better coverage) ----------
                coverageRadius = 5;      % meters
                minCoverage   = 0.98;    % 98% of STAs must be covered (strong requirement)
                alpha         = 20;      % penalty weight for missing coverage (raise if needed)
                lambda        = 0.10;    % cost for each AP (raise to use fewer APs; lower to allow more)
                beta          = 1;     % geometry (PDOP) weight
                dMin          = 3.0;     % min spacing in meters between chosen APs (avoid clustering)

                % ---------- Data-driven bounds for number of APs ----------
                areaX = [min(staXY(:,1)) max(staXY(:,1))];
                areaY = [min(staXY(:,2)) max(staXY(:,2))];
                area_m2 = max(1e-6, diff(areaX)*diff(areaY));   % guard against 0

                nCoverPerAP   = pi*(coverageRadius^2);
                roughMinAP    = ceil(minCoverage * area_m2 / nCoverPerAP * 0.5);   % conservative lower bound
                minAP_bound   = max(3, roughMinAP);                                % need >=3 for geometry
                maxAP_bound   = min(Nc, ceil(1.5 * area_m2 / nCoverPerAP));        % ceiling so GA won’t go wild
                maxAP_bound   = max(maxAP_bound, minAP_bound+1);                    % ensure feasibility

                % Linear inequality constraints for GA: A*x <= b  (x is bitstring)
                % 1) -sum(x) <= -minAP  -> sum(x) >= minAP
                % 2)  sum(x) <=  maxAP
                A = [ -ones(1, Nc);
                    ones(1, Nc) ];
                b = [ -double(minAP_bound);
                    double(maxAP_bound) ];

                % ---------------- Fitness function (same signature as apFitness.m below) ----------------
                fitnessFcn = @(bits) apFitness(bits, candXY, staXY, coverageRadius, alpha, lambda, beta, minCoverage, dMin);

                % Create diverse initial population
                initPopSize = 40;  % Much larger initial diversity
                initPop = zeros(initPopSize, Nc);

                % Strategy 1: Random uniform (50%)
                numRandom = round(initPopSize * 0.5);
                for i = 1:numRandom
                    numAPsInit = randi([minAP_bound, maxAP_bound]);
                    idx = randperm(Nc, numAPsInit);
                    initPop(i, idx) = 1;
                end

                % Strategy 2: Grid corners (25%)
                numCorners = round(initPopSize * 0.25);
                corners = [1, Nc, round(Nc/2), round(Nc/4), round(3*Nc/4)];
                for i = 1:numCorners
                    numAPsInit = randi([minAP_bound, maxAP_bound]);
                    idx = corners(randperm(length(corners), min(numAPsInit, length(corners))));
                    initPop(numRandom + i, idx) = 1;
                end

                % Strategy 3: Clustered (remaining)
                for i = (numRandom + numCorners + 1):initPopSize
                    centerIdx = randi(Nc);
                    dists = vecnorm(candXY - candXY(centerIdx,:), 2, 2);
                    [~, sortedIdx] = sort(dists);
                    numAPsInit = randi([minAP_bound, maxAP_bound]);
                    initPop(i, sortedIdx(1:numAPsInit)) = 1;
                end

                opts = optimoptions('ga', ...
                    'PopulationType', 'bitstring', ...
                    'PopulationSize', 120, ...          % Increased from 80
                    'MaxGenerations', 100, ...          % More generations for convergence
                    'EliteCount', 6, ...                % Preserve more good solutions (was 2)
                    'CrossoverFraction', 0.7, ...       % Slightly lower (was 0.8)
                    'MutationFcn', {@mutationuniform, 0.15}, ... % Lower mutation for stability (was 0.25)
                    'InitialPopulationMatrix', initPop, ...
                    'UseParallel', false, ...
                    'FunctionTolerance', 1e-6, ...      % Stop when fitness stops improving
                    'MaxStallGenerations', 20, ...      % Stop if no improvement for 20 gens
                    'Display', 'iter');


                % ---------------- Run GA with AP count bounds ----------------
                [bestBits, bestScore] = ga(fitnessFcn, Nc, [], [], [], [], [], [], [], opts);  % Remove A and b


                % Selected APs
                mask = logical(bestBits);
                APsXY = candXY(mask, :);
                fprintf('Dist=%s | Ant=%dx1 | Fusion=%s | Material=%s | GA selected %d APs.\n', ...
                     distName, antennaSizes(antIdx), char(fusionType), char(materialName), sum(mask));

                % Build AP sites
                APs = buildAPSitesFromXY(APsXY, 2.5);

                if ~exist('viewer', 'var') || ~isvalid(viewer)

                    viewer = siteviewer("SceneModel", mapFile, "Transparency", 0.25);

                end

                % Set transparency based on antenna array size

                switch antennaSizes(antIdx)
                    case 4
                        trans = 0.1; % Most solid (4x1 has most info)
                    case 2
                        trans = 0.3; % Medium
                    case 1
                        trans = 0.5; % Most transparent (1x1 has least info)
                    otherwise
                        trans = 0.25;
                end

                % Set background color based on distribution
                if distName == "uniform"
                    bgColor = [0.85, 0.90, 1.0]; % Light blue
                else
                    bgColor = [1.0, 0.90, 0.85]; % Light peach
                end

                % Create viewer with both visual cues

                viewer = siteviewer("SceneModel", mapFile, ...
                    "Transparency", trans, ...
                    "Name", sprintf("%s - %dx1 Antennas", distName, antennaSizes(antIdx)));

                % Check if viewer is valid before plotting

                if isvalid(viewer)
                    %Show APs (red) and STAs (blue)
                    show(APs); % Show the selected APs (red)
                    show(STAs, "ShowAntennaHeight", false, "IconSize", [16 16]); %     Show STAs (blue)
                end


                % --- Set STA height explicitly (helps visibility for ray engine) ---
                for kk = 1:numel(STAs)
                    p = STAs(kk).AntennaPosition;
                    STAs(kk).AntennaPosition = [p(1); p(2); 1.0];  % 1.0 m
                end

                pm = propagationModel("raytracing", ...
                    "CoordinateSystem","cartesian", ...
                    "Method","sbr",...
                    "SurfaceMaterial",materialName, ...
                    "AngularSeparation","low",...
                    "MaxNumReflections",3);   % a bit more tolerant indoors
                fprintf("          Ray tracing with material: %s\n", materialName);

                rays = raytrace(APs, STAs, pm, "Map", mapFile);

                % Quick sanity check (optional)
                if isempty(rays)
                    warning('Ray tracer returned empty. Check map units/coordinates.');
                end

                % Pick a target STA to inspect rays (middle one)
                targetSTA = ceil(numel(STAs)/2);

                hide(STAs);
                show(STAs(targetSTA),'IconSize',[32 32]);  % highlight target STA

                % Plot rays from ALL APs that actually have paths to this STA
                if iscell(rays) && size(rays,2) >= targetSTA
                    hasRayFromAP = ~cellfun(@isempty, rays(:,targetSTA));
                    if any(hasRayFromAP)
                        plot([rays{hasRayFromAP,targetSTA}], 'ColorLimits', [50 95]);
                    else
                        warning('No rays found to target STA from any AP.');
                    end
                end


                cfg = heRangingConfig('ChannelBandwidth',chanBW, ...
                    "NumTransmitAntennas", prod(txArraySize), ...
                    "SecureHELTF", false);
                user = heRangingUser;
                user.NumSpaceTimeStreams = prod(txArraySize);
                cfg.User = {user};
                txWaveform = single(heRangingWaveformGenerator(cfg));
                snrs = [0 5 10 15 20 25 30 35 40];

                [features, labels] = dlPositioningGenerateDataSet(rays, STAs, APs, cfg, snrs);

                                %% ========= CLEAN MULTI-MODAL FEATURE EXTRACTION & FUSION =========
                fprintf("          Building RSSI / AoA / ToF features (aligned with CIR)...\n");
                
                numSamples = size(features,4);
                numAP      = size(rays,1);
                numSTA     = size(rays,2);
                
                % ---- 1) Get STA positions (3D) ----
                staPos = zeros(numSTA,3);
                for s = 1:numSTA
                    staPos(s,:) = double(STAs(s).AntennaPosition(:)).';
                end
                
                % ---- 2) Map each dataset sample -> nearest STA ----
                % labels.position is 3×N (same N as numSamples)
                posLabels = double(labels.position.');    % N×3
                Dpos      = pdist2(posLabels, staPos);    % N×numSTA
                [~, sample2sta] = min(Dpos, [], 2);       % for each sample, which STA is closest?
                
                % ---- 3) Compute ONE RSSI / AoA / ToF per STA ----
                rssi_sta = nan(numSTA,1);
                tof_sta  = nan(numSTA,1);
                aoa_sta  = nan(numSTA,2);   % [az, el] per STA
                
                for s = 1:numSTA
                    pathLossAll = [];
                    delayAll    = [];
                    aoaAll      = [];
                
                    for a = 1:numAP
                        rayObj = rays{a,s};
                        if isempty(rayObj); continue; end
                
                        pathLossAll = [pathLossAll, [rayObj.PathLoss]];
                        delayAll    = [delayAll,    [rayObj.PropagationDelay]];
                        aoaAll      = [aoaAll,      [rayObj.AngleOfArrival]];
                    end
                
                    if isempty(pathLossAll)
                        % No rays → leave NaN (we'll turn NaN to 0 later)
                        continue;
                    end
                
                    rssi_sta(s) = mean(pathLossAll);      % average path loss for this STA
                    tof_sta(s)  = mean(delayAll);         % average delay
                
                    if ~isempty(aoaAll)
                        aoa_sta(s,:) = mean(aoaAll,2).';  % [az, el] average for this STA
                    end
                end
                
                % ---- 4) Build per-sample 4D tensors, aligned with CIR samples ----
                rssi4D = zeros(1,1,1,numSamples,'like',features);
                tof4D  = zeros(1,1,1,numSamples,'like',features);
                aoa4D  = zeros(1,1,2,numSamples,'like',features);  % 2 channels: az, el
                
                for n = 1:numSamples
                    s = sample2sta(n);  % which STA this sample belongs to
                
                    rssi4D(1,1,1,n) = rssi_sta(s);
                    tof4D(1,1,1,n)  = tof_sta(s);
                
                    aoa4D(1,1,1,n) = aoa_sta(s,1);   % azimuth
                    aoa4D(1,1,2,n) = aoa_sta(s,2);   % elevation
                end
                
                % Replace NaNs (from STAs with no rays) by 0 to avoid NaN in training
                rssi4D(isnan(rssi4D)) = 0;
                tof4D(isnan(tof4D))   = 0;
                aoa4D(isnan(aoa4D))   = 0;
                
                % ---- 5) Apply fusion strategy ----
                fprintf("          Applying fusion: %s\n", fusionType);
                [H,W,~,~] = size(features);
                
                switch fusionType
                    % case 'CIR_only'
                    %     fusedFeatures = features;
                    % 
                    % case 'CIR_RSSI'
                    %     rssiExp = repmat(rssi4D, [H, W, 1, 1]);      % H×W×1×N
                    %     fusedFeatures = cat(3, features, rssiExp);   % add 1 channel
                    % 
                    % case 'CIR_AoA'
                    %     aoaExp  = repmat(aoa4D,  [H, W, 1, 1]);      % H×W×2×N
                    %     fusedFeatures = cat(3, features, aoaExp);    % add 2 channels
                    % 
                    % case 'CIR_ToF'
                    %     tofExp  = repmat(tof4D,  [H, W, 1, 1]);      % H×W×1×N
                    %     fusedFeatures = cat(3, features, tofExp);    % add 1 channel
                
                    case 'CIR_RSSI_AoA_ToF'
                        rssiExp = repmat(rssi4D, [H, W, 1, 1]);      % H×W×1×N
                        aoaExp  = repmat(aoa4D,  [H, W, 1, 1]);      % H×W×2×N
                        tofExp  = repmat(tof4D,  [H, W, 1, 1]);      % H×W×1×N
                        fusedFeatures = cat(3, features, rssiExp, aoaExp, tofExp); % +4 ch
                
                    otherwise
                        error('Unknown fusion strategy: %s', fusionType);
                end
                
                features = fusedFeatures;
                fprintf('Fusion complete: %s | Feature size: %s\n', ...
                        fusionType, mat2str(size(features)));
                %% ========= END OF FUSION BLOCK =========


                disp(fieldnames(labels))
                % Ensure class field is categorical

                % 1. Make sure your class labels are categorical and are a COLUMN vector
                if ~iscategorical(labels.class)
                    labels.class = categorical(labels.class);
                end

                % 2. Count and balance
                classes = categories(labels.class);
                counts = countcats(labels.class);

                % Use median instead of min to keep more samples
                target_count = round(median(counts));

                balanced_idxs = [];
                for i = 1:length(classes)
                    idx = find(labels.class == classes{i});
                    n_samples = length(idx);

                    % Force idx to be column vector
                    idx = idx(:);

                    if n_samples >= target_count
                        % Undersample large classes
                        idx = idx(randperm(n_samples, target_count));
                    else
                        % Oversample small classes with augmentation
                        idx_original = idx(:);  % Ensure column vector
                        while length(idx) < target_count
                            % Calculate how many more samples needed
                            n_needed = min(n_samples, target_count - length(idx));

                            % Sample with replacement and ensure column vector
                            new_idx = idx_original(randperm(n_samples, n_needed));
                            new_idx = new_idx(:);  % Force column vector

                            % Concatenate
                            idx = [idx; new_idx];
                        end

                        % Trim to exact target count (in case of overshoot)
                        idx = idx(1:target_count);
                    end

                    % Ensure idx is column vector before concatenating
                    idx = idx(:);
                    balanced_idxs = [balanced_idxs; idx];
                end

                disp('Class distribution after balancing:');
                disp(countcats(labels.class(balanced_idxs)));

                % 3. Subsample everything with balanced_idxs
                features = features(:,:,:,balanced_idxs);
                labels.class = labels.class(balanced_idxs);
                labels.position = labels.position(:, balanced_idxs);  % keep columns, as you have [3, N] shape

                labels.class = labels.class(:)';     % ensures \[1, N] shape
                labels.position = labels.position(:, :);  % keeps as \[3, N]


                [training,validation] = dlPositioningSplitDataSet(features,labels,0.2);

                % ------------ FEATURE NORMALIZATION ------------
                % --- Feature Normalization and Data Split (ROBUST METHOD) ---
                mu = mean(features(:)); sigma = std(features(:));
                features = (features - mu) / (sigma + eps);

                % Create a cvpartition object
                cvp = cvpartition(labels.class, 'HoldOut', 0.2);  % 80% training, 20% testing

                % Use the training and test methods to extract indices for training and validation
                trainIdx = cvp.training;  % Indices for the training set
                valIdx = cvp.test;        % Indices for the validation set

                % Use the indices to partition your data
                training.X = features(:,:,:,trainIdx);
                training.Y.classification = labels.class(trainIdx);
                training.Y.regression = labels.position(:, trainIdx);

                validation.X = features(:,:,:,valIdx);
                validation.Y.classification = labels.class(valIdx);
                validation.Y.regression = labels.position(:, valIdx);

                % Summary of the dataset size
                disp('Dataset size summary:');

                % Check the total number of samples and features
                disp(['Total samples (N): ', num2str(size(training.X, 4))]);
                disp(['Feature dimensions (HxWxCx): ', num2str(size(training.X, 1)), 'x', num2str(size(training.X, 2)), 'x', num2str(size(training.X, 3))]);

                % Check the total number of classes
                disp(['Total number of classes: ', num2str(numel(categories(training.Y.classification)))]);

                % Check the number of training and validation samples
                disp(['Number of training samples: ', num2str(numel(training.Y.classification))]);
                disp(['Number of validation samples: ', num2str(numel(validation.Y.classification))]);

                % Display class distribution
                disp('Class distribution (training set):');
                disp(countcats(training.Y.classification));

                % Build network layers
                layers = [
                    imageInputLayer(size(training.X, 1:3), 'Normalization', 'none')
                    convolution2dLayer(3, 128, 'Padding', 'same', 'WeightL2Factor', 0.0005)
                    batchNormalizationLayer
                    reluLayer

                    convolution2dLayer(3, 128, 'Padding', 'same')
                    batchNormalizationLayer
                    reluLayer

                    averagePooling2dLayer(2, 'Stride', 2, 'Padding', 'same')

                    convolution2dLayer(3, 256, 'Padding', 'same')
                    batchNormalizationLayer
                    reluLayer

                    convolution2dLayer(3, 256, 'Padding', 'same')
                    batchNormalizationLayer
                    reluLayer

                    averagePooling2dLayer(2, 'Stride', 2, 'Padding', 'same')

                    dropoutLayer(0.35)
                    ];

                % --- LOCALIZATION TASK --- CNN Training for Localization Task
                valY = validation.Y.classification;
                trainY = training.Y.classification;
                fprintf('Training localization network...\n');
                local_layers = [layers; fullyConnectedLayer(numel(classes)); softmaxLayer];
                lossFcn = "crossentropy";
                trainingMetric = "accuracy";
                miniBatchSize = 32;
                validationFrequency = floor(size(training.X,4)/miniBatchSize);

                options = trainingOptions("adam", ...
                    "MiniBatchSize", 32, ...
                    "MaxEpochs", 10, ...
                    "InitialLearnRate", 1e-3, ...
                    "Shuffle", "every-epoch", ...
                    "ValidationData", {validation.X,valY'}, ...
                    "Verbose", true, ...
                    "ResetInputNormalization", true, ...
                    "LearnRateSchedule","piecewise", ...   % reduce LR during training
                    "LearnRateDropPeriod", 10, ...
                    "LearnRateDropFactor", 0.2, ...
                    "ValidationFrequency",validationFrequency, ...
                    "ExecutionEnvironment", "auto");
                net = trainnet(training.X, training.Y.classification.', local_layers, "crossentropy", options);

                % ----------------- PREDICT Evaluate Localization Performance -----------------
                YScores = predict(net, validation.X);
                YPred = scores2label(YScores, categories(labels.class));   % your helper

                % ----------------- Confusion chart (robust save + title + text color) -----------------
                classes = categories(labels.class);
                yTrue   = validation.Y.classification(:);
                yPred   = YPred(:);
                
                yTrue = categorical(yTrue, classes);
                yPred = categorical(yPred, classes);
                
                accPct = 100 * mean(yPred == yTrue);
                accuracyArray(antIdx) = accPct;   % store accuracy
                
                hC = figure('Color','w','Name','Confusion');
                cmFile = sprintf('confusion_%s_sep%.1f_%s_%s_%dx1_%s_acc%02d.png', ...
                    distName, staSep, materialName, fusionType, ...
                    antennaSizes(antIdx), char(chanBW), round(accPct));
                fname = fullfile(char(outDir), cmFile);
                
                try
                    % Preferred: confusionchart (new MATLAB)
                    cm = confusionchart(yTrue, yPred, 'Normalization', 'absolute');
                    
                    try
                        cm.RowSummary = 'off';
                        cm.ColumnSummary = 'off';
                        cm.XLabel = 'Predicted Class';
                        cm.YLabel = 'True Class';
                    end
                    
                    titleStr = sprintf('Acc: %.2f%% | Dist=%s | Sep=%.1f | Mat=%s | Fusion=%s | %dx1 | %s', ...
                        accPct, distName, staSep, materialName, fusionType, antennaSizes(antIdx), char(chanBW));
                    
                    try
                        cm.Title.String = titleStr;
                    catch
                        title(titleStr);
                    end
                    
                    try
                        cm.TextColor = 'black';
                    end
                    
                    % Save but DO NOT close
                    try
                        exportgraphics(hC, fname, 'Resolution', 300);
                    catch
                        try saveas(hC, fname); catch, print(hC, fname, '-dpng', '-r300'); end
                    end
                    
                    % Bring window to front and let user see it
                    figure(hC);  % focus
                    % Option 1: let code continue, user can close manually
                    % Option 2: block until user closes:
                    % waitfor(hC);
                    
                catch
                    % Fallback: manual confusion matrix
                    C = confusionmat(yTrue, yPred, 'Order', classes);
                    hHM = figure('Color','w','Name','ConfusionCounts');
                    imagesc(C); colormap(parula); axis equal tight;
                    set(gca, 'XTick', 1:numel(classes), 'XTickLabel', classes, ...
                             'YTick', 1:numel(classes), 'YTickLabel', classes, ...
                             'XTickLabelRotation', 30, 'TickLength', [0 0]);
                    xlabel('Predicted Class'); ylabel('True Class');
                    for ii = 1:size(C,1)
                        for jj = 1:size(C,2)
                            text(jj, ii, sprintf('%d', C(ii,jj)), ...
                                'HorizontalAlignment','center', 'FontWeight','bold', 'Color','k');
                        end
                    end
                    title(sprintf('Acc: %.2f%% | Dist=%s | Sep=%.1f | Mat=%s | Fusion=%s | %dx1 | %s', ...
                        accPct, distName, staSep, materialName, fusionType, antennaSizes(antIdx), char(chanBW)));
                    
                    fname = fullfile(char(outDir), cmFile);
                    try
                        exportgraphics(hHM, fname, 'Resolution', 300);
                    catch
                        try saveas(hHM, fname); catch, print(hHM, fname, '-dpng', '-r300'); end
                    end
                    
                    % Again: do NOT close automatically if you want to see it
                    figure(hHM);
                    % waitfor(hHM);  % optional
                end
                % --------------------------------------------------------------------------------------

                % distName = distribution{distIdx};
                % % (1) Snapshot figures before plotting
                % prevFigs = findall(0,'Type','figure');
                % % (2) Plot (this may open a NEW figure internally)
                % acc = dlPositioningPlotResults(mapFile, validation.Y, YPred, "localization");
                % % (3) Find the figure that was just created/used
                % newFigs = setdiff(findall(0,'Type','figure'), prevFigs);
                % if isempty(newFigs)
                %     hFig = gcf; % fallback to current
                % else
                %     hFig = newFigs(1); % take the new figure
                % end
                % % (4) Make sure accuracy is in percent

                % % (5) Put accuracy into the axes title if possible
                % axList = findall(hFig,'Type','axes');
                % if ~isempty(axList)
                %     title(axList(1), sprintf('CNN Location Prediction - %s - %dx1 | Accuracy: %.2f%%', ...
                %         distName, antennaSizes(antIdx), accPct));
                % else
                %     % No axes found (rare). Add a figure-level textbox instead.
                %     figure(hFig); drawnow;
                %     annotation('textbox',[0.15 0.90 0.3 0.05], ...
                %         'String', sprintf('Accuracy: %.2f%%', accPct), ...
                %         'FontWeight','bold','EdgeColor','none','FitBoxToText','on');
                % end
                % % (6) Save using an axes/chart handle if available; otherwise save figure
                % fname = sprintf('CNN_LocationMap_%s_%dx1.png', distName, antennaSizes(antIdx));
                % if ~isempty(axList)
                %     exportgraphics(axList(1), fname); % pass AXES to exportgraphics
                % else
                %     print(hFig, fname, '-dpng', '-r300'); % fallback
                % end
                % close(hFig);
                ypred_cell = cellstr(YPred(:));
                valY_cell = cellstr(validation.Y.classification(:));
                locErrorVec = ~strcmp(ypred_cell, valY_cell);
                [f_loc, x_loc] = ecdf(double(locErrorVec));
                localizationCDF{antIdx} = struct('f', f_loc, 'x', x_loc);

                pos_layers = [layers; fullyConnectedLayer(3)];
                lossFcn = "mse";
                valY = validation.Y.regression;
                trainY = training.Y.regression;
                options.ValidationData = {validation.X, valY'};
                net = trainnet(training.X, trainY.', pos_layers, lossFcn, options);

                YPred = predict(net, validation.X);
                trueLocs = valY; predLocs = YPred;
                if size(trueLocs,1) ~= 3, trueLocs = trueLocs'; end
                if size(predLocs,1) ~= 3, predLocs = predLocs'; end
                distErr = sqrt(sum((trueLocs' - predLocs').^2, 1));
                [f_pos, x_pos] = ecdf(distErr');
                positioningCDF{antIdx} = struct('f', f_pos, 'x', x_pos);
                meanDistErrArray(antIdx) = mean(distErr);
                
            % Save per distribution
            distName = distribution{distIdx};
            allAccuracy.(distName) = accuracyArray; % 1×numAntennaSizes
            allPositionError.(distName) = meanDistErrArray; % 1×numAntennaSizes
            allPositioningCDF.(distName)= positioningCDF; % 1×numAntennaSizes cell

            % reset holders for the next distribution run
            positioningCDF = cell(1,numel(antennaSizes));
            accuracyArray = zeros(1,numel(antennaSizes));
            meanDistErrArray= zeros(1,numel(antennaSizes));
                end
            end
        end
    end
end

        % === Final Overlays for Comparison ===
        % Build a 2×A matrix of accuracies (rows = distributions, cols = antenna sizes)
        A = numel(antennaSizes);
        accMat = zeros(numel(distribution), A);
        for d = 1:numel(distribution)
            dn = distribution{d};
            accMat(d,:) = 100 * allAccuracy.(dn); % convert to %
        end
        hBar = figure('Name','Localization accuracy — bar', 'Color','w');
        bar(accMat','grouped'); grid on;
        xlabel('Antenna size'); ylabel('Accuracy (%)');
        set(gca,'XTickLabel', strcat(string(antennaSizes),'x1')); % 4x1, 2x1, 1x1 etc.

        legend(distribution,'Location','southoutside','Orientation','horizontal');
        title('Localization accuracy by antenna and distribution');
        exportgraphics(hBar, 'summary_localization_bar.png', 'Resolution', 300);
        close(hBar);

        figPos = figure('Name','CDF - Positioning Error Comparison'); hold on;
        for d = 1:numel(distribution)
            distName = distribution{d};
            for i = 1:numel(antennaSizes)
                switch distName
                    case 'uniform'
                        color = [0.00, 0.45, 0.74; 0.93, 0.69, 0.13; 0.30, 0.75, 0.93]; % same as above
                    case 'random'
                        color = [0.85, 0.33, 0.10; 0.47, 0.67, 0.19; 0.49, 0.18, 0.56]; % same as above
                end
                plot(allPositioningCDF.(distName){i}.x, allPositioningCDF.(distName){i}.f, ...
                    'LineWidth',2, 'Color',color(i,:), ...
                    'DisplayName', sprintf('%s - %dx1', distName, antennaSizes(i)));

            end
        end
        xlabel('Distance Error (m)'); ylabel('CDF'); legend; grid on;
        title('Final CDF - Positioning Error Comparison');
        saveas(figPos, 'Final_CDF_Positioning_Comparison.jpeg');