clear; close all; clc;

rng('shuffle');

antennaSizes = [4, 2, 1];
chanBW = "CBW160";
distribution = {"uniform", "random"};

staSeparations = [0.7, 0.5, 0.25];  % STA spacing in meters

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
allPositioningCDF = struct();

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
                    baseNumSTAs = 800;
                    scaleFactor = (0.5 / staSep)^2;  % Quadratic scaling
                    numSTAs = round(baseNumSTAs * scaleFactor);
                    numSTAs = min(numSTAs, 1000);  % Cap at 5000 for computational reasons
                    
                    [APs, STAs] = dlPositioningCreateEnvironment(txArraySize, rxArraySize, numSTAs, "random");
                    fprintf("          Random STAs generated: %d\n", numSTAs);
                end
                
                fprintf("          Actual STAs created: %d\n", numel(STAs));

                    % Add noise to STA positions to simulate random jitter
                
                % % Add noise to STA positions to simulate random jitter
                %     noiseLevel = 0.1;  % Noise level for jitter in meters
                %     for i = 1:numel(STAs)
                %         originalPos = STAs(i).AntennaPosition;  % Get the current 3D position [x, y, z]
                % 
                %         % Add noise to the x and y coordinates, keeping z fixed
                %         noise = noiseLevel * randn(1, 2);  % Random jitter for x and y (2D)
                % 
                %         % Ensure z remains unchanged, and only jitter x and y
                %         STAs(i).AntennaPosition = [originalPos(1) + noise(1), originalPos(2) + noise(2), originalPos(3)];
                %     end

                %single objective 
                % %% ------------------- GA-Based AP Placement -------------------
                % % Ensure STA coordinates are defined
                % N = numel(STAs);
                % staXY = zeros(N, 2);
                % for k = 1:N
                %     p = STAs(k).AntennaPosition;
                %     staXY(k, :) = double(p(1:2)).';
                % end
                % 
                % % Candidate AP positions
                % margin = 0.5; gridStep = 1.5;
                % area = [min(staXY(:,1))-margin, max(staXY(:,1))+margin, ...
                %     min(staXY(:,2))-margin, max(staXY(:,2))+margin];
                % xs = area(1):gridStep:area(2);
                % ys = area(3):gridStep:area(4);
                % [XX, YY] = meshgrid(xs, ys);
                % candXY = [XX(:), YY(:)];
                % Nc = size(candXY, 1);
                % 
                % % ---------- Coverage target & GA weighting (edit these to demand better coverage) ----------
                % coverageRadius = 5;      % meters
                % minCoverage   = 0.98;    % 98% of STAs must be covered (strong requirement)
                % alpha         = 20;      % penalty weight for missing coverage (raise if needed)
                % lambda        = 0.10;    % cost for each AP (raise to use fewer APs; lower to allow more)
                % beta          = 1;     % geometry (PDOP) weight
                % dMin          = 3.0;     % min spacing in meters between chosen APs (avoid clustering)
                % 
                % % ---------- Data-driven bounds for number of APs ----------
                % areaX = [min(staXY(:,1)) max(staXY(:,1))];
                % areaY = [min(staXY(:,2)) max(staXY(:,2))];
                % area_m2 = max(1e-6, diff(areaX)*diff(areaY));   % guard against 0
                % 
                % nCoverPerAP   = pi*(coverageRadius^2);
                % roughMinAP    = ceil(minCoverage * area_m2 / nCoverPerAP * 0.5);   % conservative lower bound
                % minAP_bound   = max(3, roughMinAP);                                % need >=3 for geometry
                % maxAP_bound   = min(Nc, ceil(1.5 * area_m2 / nCoverPerAP));        % ceiling so GA won’t go wild
                % maxAP_bound   = max(maxAP_bound, minAP_bound+1);                    % ensure feasibility
                % 
                % % Linear inequality constraints for GA: A*x <= b  (x is bitstring)
                % % 1) -sum(x) <= -minAP  -> sum(x) >= minAP
                % % 2)  sum(x) <=  maxAP
                % A = [ -ones(1, Nc);
                %     ones(1, Nc) ];
                % b = [ -double(minAP_bound);
                %     double(maxAP_bound) ];
                % 
                % % ---------------- Fitness function (same signature as apFitness.m below) ----------------
                % fitnessFcn = @(bits) apFitness(bits, candXY, staXY, coverageRadius, alpha, lambda, beta, minCoverage, dMin);
                % 
                % % Create diverse initial population
                % initPopSize = 40;  % Much larger initial diversity
                % initPop = zeros(initPopSize, Nc);
                % 
                % % Strategy 1: Random uniform (50%)
                % numRandom = round(initPopSize * 0.5);
                % for i = 1:numRandom
                %     numAPsInit = randi([minAP_bound, maxAP_bound]);
                %     idx = randperm(Nc, numAPsInit);
                %     initPop(i, idx) = 1;
                % end
                % 
                % % Strategy 2: Grid corners (25%)
                % numCorners = round(initPopSize * 0.25);
                % corners = [1, Nc, round(Nc/2), round(Nc/4), round(3*Nc/4)];
                % for i = 1:numCorners
                %     numAPsInit = randi([minAP_bound, maxAP_bound]);
                %     idx = corners(randperm(length(corners), min(numAPsInit, length(corners))));
                %     initPop(numRandom + i, idx) = 1;
                % end
                % 
                % % Strategy 3: Clustered (remaining)
                % for i = (numRandom + numCorners + 1):initPopSize
                %     centerIdx = randi(Nc);
                %     dists = vecnorm(candXY - candXY(centerIdx,:), 2, 2);
                %     [~, sortedIdx] = sort(dists);
                %     numAPsInit = randi([minAP_bound, maxAP_bound]);
                %     initPop(i, sortedIdx(1:numAPsInit)) = 1;
                % end
                % 
                % opts = optimoptions('ga', ...
                %     'PopulationType', 'bitstring', ...
                %     'PopulationSize', 80, ...          % Increased from 80
                %     'MaxGenerations', 60, ...          % More generations for convergence
                %     'EliteCount', 6, ...                % Preserve more good solutions (was 2)
                %     'CrossoverFraction', 0.7, ...       % Slightly lower (was 0.8)
                %     'MutationFcn', {@mutationuniform, 0.15}, ... % Lower mutation for stability (was 0.25)
                %     'InitialPopulationMatrix', initPop, ...
                %     'UseParallel', false, ...
                %     'FunctionTolerance', 1e-6, ...      % Stop when fitness stops improving
                %     'MaxStallGenerations', 20, ...      % Stop if no improvement for 20 gens
                %     'Display', 'iter');
                % 
                % 
                % % ---------------- Run GA with AP count bounds ----------------
                % [bestBits, bestScore] = ga(fitnessFcn, Nc, A, b, [], [], [], [], [], opts);
                %   % Remove A and b
                % 
                % 
                % % Selected APs
                % mask = logical(bestBits);
                % APsXY = candXY(mask, :);
                % fprintf('Dist=%s | Ant=%dx1 | Fusion=%s | Material=%s | GA selected %d APs.\n', ...
                %      distName, antennaSizes(antIdx), char(fusionType), char(materialName), sum(mask));
                % 
                % % Build AP sites
                % APs = buildAPSitesFromXY(APsXY, 2.5);

                %% ------------------- MO-GA AP Placement (Pareto) -------------------
                % Derive basic GA parameters automatically from the environment & rays
                paramsGA = struct();
                
                % --- read frequency & Tx power from current AP objects if possible ---
                try
                    paramsGA.fc = APs(1).TransmitterFrequency;        % Hz
                catch
                    paramsGA.fc = 5.18e9;  % fallback
                end
                
                try
                    paramsGA.TxPower_dBm = APs(1).TransmitterPower;   % dBm (if set)
                catch
                    paramsGA.TxPower_dBm = 20;                        % fallback (matches your code)
                end
                
                % --- map geometry / candidate grid derived from STA extents (automatic) ---
                paramsGA.margin     = 0.5;     % used to enlarge candidate area around STA cloud
                paramsGA.gridStep   = 1.5;     % candidate spacing (tradeoff speed vs quality)
                paramsGA.APheight   = 2.5;     % meters
                
                % --- ray-tracing settings for AP planning ---
                paramsGA.maxReflections = 3;
                
                % --- coverage model parameters (automatic decision still, but fixed physics knobs) ---
                paramsGA.RxSensitivity  = -75;    % dBm threshold for -covered" (adjust if needed globally)
                paramsGA.minCoverage    = 0.98;   % required coverage ratio
                
                % --- spacing constraint to avoid AP clustering ---
                paramsGA.dMin           = 3.0;    % meters
                
                % --- Multi-objective decision output count (AUTOMATIC choices will be returned) ---
                K = 4;   % internally choose 3 4best” Pareto points: max-coverage, min-cost, knee
                
                % Run MO planner -> returns multiple AP layouts + objective values
                [APsSet, paretoObj, paretoMeta] = planAccessPoints_MO_GA_auto( ...
                     STAs, mapFile, materialName, paramsGA, txArraySize, K);

                
                % Pick which layout to USE for dataset/training:
                % Default: knee/compromise solution (3rd returned if available), else first.
                useIdx = find(paretoMeta.solutionLabels == "KneeCompromise", 1);
                if isempty(useIdx), useIdx = 1; end
                APs = APsSet{useIdx};
                
                fprintf("MAIN picked: %s (useIdx=%d) | APs=%d | txArray=%dx%d\n", ...
                     paretoMeta.solutionLabels(useIdx), useIdx, numel(APs), txArraySize(1), txArraySize(2));

                    % (optional) add useIdx to your file naming so outputs don't overwrite
                runTag = sprintf("_MOsol%d", useIdx);
                
                    % then run raytrace/dataset/training as usual...
    
                fprintf("MO-GA selected %d candidate solutions; using solution #%d with %d APs.\n", ...
                    numel(APsSet), useIdx, numel(APs));
                
                % Save all candidate solutions so you can compare later
                solTag = sprintf("MO_%s_sep%.1f_%s_%s_%dx1_%s", distName, staSep, materialName, fusionType, ...
                                 antennaSizes(antIdx), char(chanBW));
                
                save(fullfile(outDir, solTag + "_APsolutions.mat"), ...
                     "APsSet", "paretoObj", "paretoMeta", "paramsGA");
%% ------------------------------------------------------------------

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

                % compute coverage on FULL STAs using same RSSI model
                NsFull = numel(STAs);
                covered = false(NsFull,1);
                
                arrayGain_dB = 10*log10(prod(txArraySize));   % same definition as planner
                
                for s = 1:NsFull
                    bestRSSI = -inf;
                    for a = 1:numel(APs)
                        rr = rays{a,s};
                        if isempty(rr), continue; end
                        plMin = min([rr.PathLoss]);
                
                                % --- EIRP-limited RSSI model ---
                        eirpLimit_dBm = paramsGA.TxPower_dBm;
                        rssi_s = eirpLimit_dBm - plMin;

                        
                        if rssi_s > bestRSSI
                            bestRSSI = rssi_s;
                        end
                    end
                    covered(s) = (bestRSSI >= paramsGA.RxSensitivity);
                end
                
                covFull = mean(covered);
                
                fprintf("FULL-STA VALIDATION | txArray=%dx%d | APs=%d | Coverage=%.4f (target=%.2f)\n", ...
                    txArraySize(1), txArraySize(2), numel(APs), covFull, paramsGA.minCoverage);
                % ================================================================

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

                % Generate features and labels from dataset
                [features, labels] = dlPositioningGenerateDataSet(rays, STAs, APs, cfg, snrs);
                
                % Add noise to the features (RSSI, AoA, ToF) to simulate measurement noise
                noiseLevel = 0.02;  % Noise level (5%)
                
                % Ensure features are 4D
                if ndims(features) < 4
                    features = reshape(features, [size(features), 1]);  % Add singleton dimension
                end
                disp(size(features));
                % Initialize newFeatures with the same size and type as features
                newFeatures = zeros(size(features), 'like', features);  % 4D tensor (same size as features)
                disp(size(newFeatures));  % Print the size of newFeatures
                % Loop through each sample (i) and add noise
                for i = 1:size(features, 4)  % Iterate over the 4th dimension (samples)
                    % Add noise to each sample in the 4th dimension
                    newFeatures(:,:,:,i) = features(:,:,:,i) + noiseLevel * randn(size(features(:,:,:,i)));  
                end



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

                    bestPL   = inf;        % best (minimum) path loss
                    bestToF  = NaN;
                    bestAoA  = [NaN; NaN];
                
                    for a = 1:numAP
                        rayObj = rays{a,s};
                        if isempty(rayObj), continue; end
                
                        % --- Collect per-path values ---
                        pl  = [rayObj.PathLoss];            % 1 x K
                        d   = [rayObj.PropagationDelay];    % 1 x K
                        aoa = [rayObj.AngleOfArrival];      % 2 x K
                
                        % --- Strongest path = minimum path loss ---
                        [plMin, iBest] = min(pl);
                
                        if plMin < bestPL
                            bestPL  = plMin;
                            bestToF = d(iBest);
                            bestAoA = aoa(:, iBest);
                        end
                    end
                
                    % --- Save STA features (only if at least one ray existed) ---
                    if isfinite(bestPL)
                        txP = 20; % same as your TxPower_dBm
                        rssi_sta(s) = txP - bestPL;      % ✅ CORRECT RSSI
                        tof_sta(s)  = bestToF;
                        aoa_sta(s,:) = bestAoA(:).';
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

                % === REMOVE CLASS "0" COMPLETELY ===
                % (drop all samples whose label is the string '0')
                idxZero = labels.class == '0';              % works if label text is "0"
                % If your labels were numeric 0 originally, this also works:
                idxZero = idxZero | labels.class == categorical(0);
                
                keepIdx = ~idxZero;
                
                features        = features(:,:,:,keepIdx);
                labels.class    = labels.class(keepIdx);
                labels.position = labels.position(:, keepIdx);
                
                % Remove the unused category "0" from the categorical type
                labels.class = removecats(labels.class);
                % 2. Count and balance
                classes = categories(labels.class);
                counts = countcats(labels.class);

                % maxPerClass = 7000;
                % target_count = min(maxPerClass, round(median(counts)));

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

               % ==== DATASET AUGMENTATION: FEATURES + LABELS TOGETHER ====
                numOriginal = size(features, 4);     % current number of samples
                augFactor  = 1;                      % how many times to replicate (try 2 or 3 first)
                numSamples = numOriginal * augFactor;
                
                [H,W,C,~] = size(features);
                
                features_aug = zeros(H, W, C, numSamples, 'like', features);
                labels_aug_class    = categorical(zeros(1, numSamples));
                labels_aug_position = zeros(size(labels.position,1), numSamples, 'like', labels.position);
                
                for i = 1:numSamples
                    sampleIdx = mod(i-1, numOriginal) + 1;
                
                    oneSample = features(:,:,:,sampleIdx);
                
                    % --- CIR delay-axis shift (very important for ToF robustness) ---
                    shift = randi([-2 2]);                 % small bin shift
                    shiftedSample = circshift(oneSample, [0 shift 0]);
                
                    % --- Add noise ---
                    features_aug(:,:,:,i) = shiftedSample + noiseLevel * randn(size(oneSample));
                
                    % --- Copy labels ---
                    labels_aug_class(i)      = labels.class(sampleIdx);
                    labels_aug_position(:,i) = labels.position(:, sampleIdx);
                end

                
                % Overwrite original
                features        = features_aug;
                labels.class    = labels_aug_class;
                labels.position = labels_aug_position;
                
                fprintf('Dataset augmented by factor %d: %d -> %d samples\n', ...
                        augFactor, numOriginal, numSamples);
                %==== END AUGMENTATION BLOCK ====
                %===================== RECOMPUTE sample2sta (FINAL DATASET) =====================
                numSamplesFinal = size(features,4);

                % --- STA positions ---
                numSTA = numel(STAs);
                staPos = zeros(numSTA,3);
                for s = 1:numSTA
                    staPos(s,:) = double(STAs(s).AntennaPosition(:)).';
                end

                % --- Sample positions (Nx3) ---
                posLabels = double(labels.position(:,1:numSamplesFinal).');   % N x 3

                % --- Map each sample -> nearest STA ---
                Dpos = pdist2(posLabels, staPos);      % N x numSTA
                [~, sample2sta] = min(Dpos, [], 2);    % N x 1

                % --- Split by STA (NOT random samples) ---
                valFrac = 0.2;
                permSTA = randperm(numSTA);
                nValSTA = max(1, round(valFrac*numSTA));

                valSTA   = permSTA(1:nValSTA);
                trainSTA = permSTA(nValSTA+1:end);

                isVal    = ismember(sample2sta, valSTA);
                trainIdx = find(~isVal);
                valIdx   = find(isVal);

                trainClasses = categories(removecats(labels.class(trainIdx)));
                valClasses   = categories(removecats(labels.class(valIdx)));

                missingInVal = setdiff(trainClasses, valClasses);
                if ~isempty(missingInVal)
                    fprintf("WARNING: Validation missing classes: %s\n", strjoin(missingInVal, ", "));
                end

                
                fprintf("Split-by-STA: Train=%d | Val=%d | Total=%d\n", ...
                    numel(trainIdx), numel(valIdx), numSamplesFinal);
                
                % Safety check
                assert(max([trainIdx; valIdx]) <= numSamplesFinal, ...
                       "Index exceeds feature count!");
                % =====================================================================


                % [training,validation] = dlPositioningSplitDataSet(features,labels,0.2);

                % ======= APPLY STA-GROUP SPLIT (instead of random split) =======
                training.X = features(:,:,:,trainIdx);
                training.Y.classification = labels.class(trainIdx);
                training.Y.regression     = labels.position(:,trainIdx).';   % N x 3
                
                validation.X = features(:,:,:,valIdx);
                validation.Y.classification = labels.class(valIdx);
                validation.Y.regression     = labels.position(:,valIdx).';   % N x 3
                % =============================================================


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

              %% ========= RESNET-18 BASED LOCALIZATION (CLASSIFICATION) =========

                % Get class names and number of classes from TRAINING set
                
                training.Y.classification = removecats(training.Y.classification);
                
                % Use training's classes as the master list
                classNames = categories(training.Y.classification);
                
                % Force validation labels to have the SAME categories (even if some are absent)
                validation.Y.classification = categorical(validation.Y.classification, classNames);
                % =========================================================================

                numClasses = numel(classNames);
                
                fprintf('Training localization network with ResNet-18...\n');
                
                % Input feature size H×W×C of your fused features
                inputSize = size(training.X, 1:3);   % [H W C]
                
                % --- Load base ResNet-18 ---
                netRes = resnet18;                   % requires Deep Learning Toolbox ResNet-18 support package
                lgraph = layerGraph(netRes);
                
                %% 2. Replace input layer to accept [H W C] instead of [224 224 3]
                origInput = lgraph.Layers(1);        % usually 'data' or 'input_1'
                newInput  = imageInputLayer(inputSize, ...
                    'Name', origInput.Name, ...
                    'Normalization','none');         % you already normalize outside
                
                lgraph = replaceLayer(lgraph, origInput.Name, newInput);
                
                %% 3. Adapt the first conv layer to C channels
                origConv = lgraph.Layers(2);         % first conv layer
                Ctarget  = inputSize(3);             % your fused #channels (e.g. CIR+RSSI+AoA+ToF)
                
                w = origConv.Weights;                % size: [k k 3 64] for standard ResNet-18
                cOrig = size(w,3);                   % 3
                
                % Replicate along channel dimension and crop to Ctarget
                repFactor = ceil(Ctarget / cOrig);
                wRep = repmat(w, 1, 1, repFactor, 1);      % [k k (3*repFactor) 64]
                wNew = wRep(:,:,1:Ctarget,:) * (cOrig / Ctarget);  % rescale to keep energy similar
                
                newConv = convolution2dLayer(origConv.FilterSize, origConv.NumFilters, ...
                    'Stride',         origConv.Stride, ...
                    'Padding',        origConv.PaddingSize, ...
                    'BiasLearnRateFactor', origConv.BiasLearnRateFactor, ...
                    'BiasL2Factor',        origConv.BiasL2Factor, ...
                    'Name',           origConv.Name);
                
                newConv.Weights = wNew;
                newConv.Bias    = origConv.Bias;
                
                lgraph = replaceLayer(lgraph, origConv.Name, newConv);
                
                %% 4. Replace the classification head with your own
                % Remove original head
                lgraph = removeLayers(lgraph, {'fc1000','prob','ClassificationLayer_predictions'});
                
                % Add new head for numClasses
                newHead = [
                    fullyConnectedLayer(numClasses,'Name','fc_out')
                    softmaxLayer('Name','softmax')
                    classificationLayer('Name','classoutput')
                ];
                
                lgraph = addLayers(lgraph, newHead);
                lgraph = connectLayers(lgraph, 'pool5', 'fc_out');
                
                %% 5. Train using trainNetwork (NOT trainnet)
                miniBatchSize       = 32;
                validationFrequency = floor(size(training.X,4)/miniBatchSize);
                
                options = trainingOptions("adam", ...
                    "MiniBatchSize", miniBatchSize, ...
                    "MaxEpochs", 15, ...
                    "InitialLearnRate", 5e-4, ...
                    "Shuffle", "every-epoch", ...
                    "ValidationData", {validation.X, validation.Y.classification}, ...
                    "Verbose", true, ...
                    "ResetInputNormalization", true, ...
                    "LearnRateSchedule","piecewise", ...
                    "LearnRateDropPeriod", 10, ...
                    "LearnRateDropFactor", 0.2, ...
                    "ValidationFrequency",validationFrequency, ...
                    "ExecutionEnvironment", "auto");
                
                % Train ResNet-18 classifier
                net = trainNetwork(training.X, training.Y.classification, lgraph, options);

                % % --- Build confusion matrix WITHOUT the '0' class ---
                % YScores = predict(net, validation.X);
                % YPred   = scores2label(YScores, classNames);
                % 
                % % Ground truth
                % yTrue = validation.Y.classification(:);
                % 
                % % Start from all classes present in training
                % allClasses = categories(training.Y.classification);
                % 
                % % Remove the unwanted '0' class from the list
                % keepClasses = allClasses(~strcmp(allClasses,'0'));
                % 
                % % Map yTrue and YPred into categoricals using ONLY the 7 classes
                % yTrue = categorical(yTrue, keepClasses);      % undefined if it was '0'
                % yPred = categorical(YPred(:), keepClasses);   % undefined if model predicts '0'
                % 
                % % Now compute accuracy only on defined entries (non-'0' ground truth)
                % validMask = ~isundefined(yTrue);
                % yTrueValid = yTrue(validMask);
                % yPredValid = yPred(validMask);
                % 
                % accPct = 100 * mean(yPredValid == yTrueValid);
                % 
                % % Confusion matrix and confusion chart with 7 classes only
                % C = confusionmat(yTrueValid, yPredValid, 'Order', keepClasses);
                % 
                % hC = figure('Color','w','Name','Confusion');
                % cm = confusionchart(yTrueValid, yPredValid, ...
                %     'Order', keepClasses, ...
                %     'Normalization','absolute');
                % cm.RowSummary    = 'off';
                % cm.ColumnSummary = 'off';
                % cm.XLabel = 'Predicted Class';
                % cm.YLabel = 'True Class';
                % 
                % titleStr = sprintf('Acc: %.2f%% | Dist=%s | Sep=%.1f | Mat=%s | Fusion=%s | %dx1 | %s', ...
                %     accPct, distName, staSep, materialName, fusionType, antennaSizes(antIdx), char(chanBW));
                % cm.Title = titleStr;
                % 
                % accFromC = sum(diag(C)) / sum(C(:)) * 100;
                % fprintf('Accuracy from confusion matrix diag: %.2f%%\n', accFromC);
                % 
                % 
                % %% === SANITY CHECK 3: random baseline classifier ===
                % nVal    = numel(yTrue);
                % randIdx = randi(numel(classes), nVal, 1);
                % yPredRand = categorical(classes(randIdx), classes);
                % 
                % accRand = 100 * mean(yPredRand == yTrue);
                % fprintf('Random baseline accuracy on same val set: %.2f%% (expect ~%.2f%% for %d classes)\n', ...
                %     accRand, 100/numel(classes), numel(classes));
                % %% === END SANITY CHECK 3 ===
                % 
                % 
                % hC = figure('Color','w','Name','Confusion');
                % cmFile = sprintf('confusion_%s_sep%.1f_%s_%s_%dx1_%s_acc%02d.png', ...
                %     distName, staSep, materialName, fusionType, ...
                %     antennaSizes(antIdx), char(chanBW), round(accPct));
                % fname = fullfile(char(outDir), cmFile);
                % 
                % % try
                % %     % Preferred: confusionchart (new MATLAB)
                % %     cm = confusionchart(yTrue, yPred, 'Order', categories(yTrue));
                % % 
                % % 
                % %     try
                % %         cm.RowSummary = 'off';
                % %         cm.ColumnSummary = 'off';
                % %         cm.XLabel = 'Predicted Class';
                % %         cm.YLabel = 'True Class';
                % %     end
                % % 
                % %     titleStr = sprintf('Acc: %.2f%% | Dist=%s | Sep=%.1f | Mat=%s | Fusion=%s | %dx1 | %s', ...
                % %         accPct, distName, staSep, materialName, fusionType, antennaSizes(antIdx), char(chanBW));
                % % 
                % %     try
                % %         cm.Title.String = titleStr;
                % %     catch
                % %         title(titleStr);
                % %     end
                % % 
                % %     try
                % %         cm.TextColor = 'black';
                % %     end
                % % 
                % %     % Save but DO NOT close
                % %     try
                % %         exportgraphics(hC, fname, 'Resolution', 300);
                % %     catch
                % %         try saveas(hC, fname); catch, print(hC, fname, '-dpng', '-r300'); end
                % %     end
                % % 
                % %     % Bring window to front and let user see it
                % %     figure(hC);  % focus
                % %     % Option 1: let code continue, user can close manually
                % %     % Option 2: block until user closes:
                % %     % waitfor(hC);
                % % 
                % % catch
                % %     % Fallback: manual confusion matrix
                % %     C = confusionmat(yTrue, yPred, 'Order', classes);
                % %     hHM = figure('Color','w','Name','ConfusionCounts');
                % %     imagesc(C); colormap(parula); axis equal tight;
                % %     set(gca, 'XTick', 1:numel(classes), 'XTickLabel', classes, ...
                % %              'YTick', 1:numel(classes), 'YTickLabel', classes, ...
                % %              'XTickLabelRotation', 30, 'TickLength', [0 0]);
                % %     xlabel('Predicted Class'); ylabel('True Class');
                % %     for ii = 1:size(C,1)
                % %         for jj = 1:size(C,2)
                % %             text(jj, ii, sprintf('%d', C(ii,jj)), ...
                % %                 'HorizontalAlignment','center', 'FontWeight','bold', 'Color','k');
                % %         end
                % %     end
                % %     title(sprintf('Acc: %.2f%% | Dist=%s | Sep=%.1f | Mat=%s | Fusion=%s | %dx1 | %s', ...
                % %         accPct, distName, staSep, materialName, fusionType, antennaSizes(antIdx), char(chanBW)));
                % % 
                % %     fname = fullfile(char(outDir), cmFile);
                % %     try
                % %         exportgraphics(hHM, fname, 'Resolution', 300);
                % %     catch
                % %         try saveas(hHM, fname); catch, print(hHM, fname, '-dpng', '-r300'); end
                % %     end
                % % 
                % %     % Again: do NOT close automatically if you want to see it
                % %     figure(hHM);
                % %     % waitfor(hHM);  % optional
                % % end
                % % % --------------------------------------------------------------------------------------
                % 
                % % distName = distribution{distIdx};
                % % % (1) Snapshot figures before plotting
                % % prevFigs = findall(0,'Type','figure');
                % % % (2) Plot (this may open a NEW figure internally)
                % % acc = dlPositioningPlotResults(mapFile, validation.Y, YPred, "localization");
                % % % (3) Find the figure that was just created/used
                % % newFigs = setdiff(findall(0,'Type','figure'), prevFigs);
                % % if isempty(newFigs)
                % %     hFig = gcf; % fallback to current
                % % else
                % %     hFig = newFigs(1); % take the new figure
                % % end
                % % % (4) Make sure accuracy is in percent
                % 
                % % % (5) Put accuracy into the axes title if possible
                % % axList = findall(hFig,'Type','axes');
                % % if ~isempty(axList)
                % %     title(axList(1), sprintf('CNN Location Prediction - %s - %dx1 | Accuracy: %.2f%%', ...
                % %         distName, antennaSizes(antIdx), accPct));
                % % else
                % %     % No axes found (rare). Add a figure-level textbox instead.
                % %     figure(hFig); drawnow;
                % %     annotation('textbox',[0.15 0.90 0.3 0.05], ...
                % %         'String', sprintf('Accuracy: %.2f%%', accPct), ...
                % %         'FontWeight','bold','EdgeColor','none','FitBoxToText','on');
                % % end
                % % % (6) Save using an axes/chart handle if available; otherwise save figure
                % % fname = sprintf('CNN_LocationMap_%s_%dx1.png', distName, antennaSizes(antIdx));
                % % if ~isempty(axList)
                % %     exportgraphics(axList(1), fname); % pass AXES to exportgraphics
                % % else
                % %     print(hFig, fname, '-dpng', '-r300'); % fallback
                % % end
                % % close(hFig);
                % ypred_cell = cellstr(YPred(:));
                % valY_cell = cellstr(validation.Y.classification(:));
                % locErrorVec = ~strcmp(ypred_cell, valY_cell);
                % [f_loc, x_loc] = ecdf(double(locErrorVec));
                % localizationCDF{antIdx} = struct('f', f_loc, 'x', x_loc)
                % 
                % % Predict for validation
                % YPred = predict(net, validation.X);  % Make predictions on the validation data
                % 
                % 
                % % Remove the first row and first column (unwanted "0" class)
                % confMatrixReduced = C(2:end, 2:end);
                % 
                % % Plot and save the confusion matrix
                % figure;
                % imagesc(confMatrixReduced); 
                % colormap('jet');
                % colorbar;
                % axis equal tight;
                % 
                % % Adjust labels for the remaining classes (skip "0" class)
                % xticklabels({'office', 'storage', 'desk1', 'desk2', 'desk3'});
                % yticklabels({'office', 'storage', 'desk1', 'desk2', 'desk3'});
                % 
                % xlabel('Predicted Class');
                % ylabel('True Class');
                % title('Confusion Matrix without the "0" Class');
                % 
                % % Save the figure to a file instead of displaying it
                % saveas(gcf, 'confusion_matrix.png');
                % 
                % % Optionally: Display an accuracy summary in the command window
                % accuracy = sum(diag(C)) / sum(C(:)) * 100; % Accuracy from confusion matrix
                % disp(['Accuracy from confusion matrix: ', num2str(accuracy), '%']);

                % --- Build confusion matrix WITHOUT the '0' class ---

                % 1) Predict scores and labels
                YScores = predict(net, validation.X);
                YPred   = scores2label(YScores, classNames);   % classNames from training
                
                % 2) Ground truth labels (as they come from the split)
                yTrueAll = validation.Y.classification(:);
                
                % 3) All classes present in training
                allClasses  = categories(training.Y.classification);
                
                % 4) Keep only the real 7 room/desk classes (drop '0')
                keepClasses = allClasses(~strcmp(allClasses,"0"));
                
                % 5) Build categoricals over full class set, then drop samples with true '0'
                yTrueFull = categorical(yTrueAll, allClasses);
                yPredFull = categorical(YPred(:),  allClasses);
                
                maskKeep  = (yTrueFull ~= categorical("0"));   % keep only non-zero GT
                yTrue     = categorical(yTrueFull(maskKeep), keepClasses);
                yPred     = categorical(yPredFull(maskKeep),  keepClasses);
                
                % 6) Accuracy on the filtered (non-zero) set
                accPct = 100 * mean(yPred == yTrue);
                
                % Confusion matrix with explicit order for numeric computation
                C = confusionmat(yTrue, yPred, 'Order', keepClasses);
                
                % Confusion chart – no 'Order' argument (older MATLAB)
                hC = figure('Color','w','Name','Confusion');
                cm = confusionchart(yTrue, yPred, 'Normalization','absolute');
                
                % Try to set optional properties (if supported in your version)
                try
                    cm.RowSummary    = 'off';
                    cm.ColumnSummary = 'off';
                catch
                    % Older versions may not have these properties – just ignore
                end
                
                cm.XLabel = 'Predicted Class';
                cm.YLabel = 'True Class';
                
                titleStr = sprintf('Acc: %.2f%% | Dist=%s | Sep=%.1f | Mat=%s | Fusion=%s | %dx1 | %s', ...
                    accPct, distName, staSep, materialName, fusionType, antennaSizes(antIdx), char(chanBW));
                
                try
                    cm.Title = titleStr;
                catch
                    title(titleStr);
                end
                
                % also print accuracy from C (should match accPct)
                accFromC = sum(diag(C)) / sum(C(:)) * 100;
                fprintf('Accuracy from confusion matrix diag: %.2f%%\n', accFromC);
                
                % 8) Random baseline sanity check (over the same 7 classes)
                nVal      = numel(yTrue);
                randIdx   = randi(numel(keepClasses), nVal, 1);
                yPredRand = categorical(keepClasses(randIdx), keepClasses);
                
                accRand = 100 * mean(yPredRand == yTrue);
                fprintf('Random baseline accuracy on same val set: %.2f%% (expect ~%.2f%% for %d classes)\n', ...
                    accRand, 100/numel(keepClasses), numel(keepClasses));
                
                % 9) Save confusion figure
                cmFile = sprintf('confusion_%s_sep%.1f_%s_%s_%dx1_%s_acc%02d.png', ...
                    distName, staSep, materialName, fusionType, ...
                    antennaSizes(antIdx), char(chanBW), round(accPct));
                fname = fullfile(char(outDir), cmFile);
                try
                    exportgraphics(hC, fname, 'Resolution', 300);
                catch
                    try saveas(hC, fname); catch, print(hC, fname, '-dpng', '-r300'); end
                end
                
                % 10) Localization CDF (0 = correct, 1 = wrong) based on filtered labels
                locErrorVec = (yPred ~= yTrue);
                [f_loc, x_loc] = ecdf(double(locErrorVec));
                localizationCDF{antIdx} = struct('f', f_loc, 'x', x_loc);



                %% ========= POSITION REGRESSION WITH A SMALL CNN (SEPARATE FROM RESNET) =========
                inputSize = size(training.X,1:3);   % [H W C] of your fused CIR features
                
                regLayers = [
                    imageInputLayer(inputSize, ...
                        'Normalization','none', ...
                        'Name','input_reg')
                
                    convolution2dLayer(3, 64, 'Padding','same', 'Name','conv1_reg')
                    reluLayer('Name','relu1_reg')
                
                    convolution2dLayer(3, 128, 'Padding','same', 'Name','conv2_reg')
                    reluLayer('Name','relu2_reg')
                
                    % This works even if H = 1 (no fixed pool size)
                    globalAveragePooling2dLayer('Name','gap_reg')
                
                    fullyConnectedLayer(64,'Name','fc1_reg')
                    reluLayer('Name','relu3_reg')
                
                    fullyConnectedLayer(3,'Name','fc_out_reg')   % outputs [x, y, z]
                ];
                
                % Convert to dlnetwork for trainnet
                dlNetReg = dlnetwork(regLayers);
                
                lossFcn = "mse";
                
                % Targets must be N×3 (N = size(training.X,4))
                trainY = single(training.Y.regression);      % ✅ N×3
                valY   = single(validation.Y.regression);    % ✅ N×3

                % --- REGRESSION TRAINING OPTIONS ---
                optsReg = trainingOptions("adam", ...
                    "MiniBatchSize", 64, ...
                    "MaxEpochs", 10, ...
                    "InitialLearnRate", 1e-3, ...
                    "Shuffle","every-epoch", ...
                    "ValidationData",{validation.X, valY}, ...
                    "Verbose", true, ...
                    "ExecutionEnvironment","auto");
                
                fprintf("Training regression network...\n");
                
                % sanity checks (keep these!)
                assert(size(trainY,1) == size(training.X,4), ...
                    "Mismatch: trainY rows must equal size(training.X,4)");
                assert(size(valY,1) == size(validation.X,4), ...
                    "Mismatch: valY rows must equal size(validation.X,4)");

                
                options.ValidationData = {validation.X, valY};
                
                fprintf('Training regression network...\n');
                netPos = trainnet(training.X, trainY, dlNetReg, "mse", optsReg);
                
                % ---------- Evaluate positioning ----------
                YPredPos = predict(netPos, validation.X);  % N×3
                
                trueLocs = valY;      % N×3
                predLocs = YPredPos;  % N×3
                
                distErr = sqrt(sum((trueLocs - predLocs).^2, 2));  % N×1
                medErr  = median(distErr);
                p90Err  = prctile(distErr, 90);
                p95Err  = prctile(distErr, 95);
                
                fprintf("REGRESSION | %s | Sep=%.1f | Mat=%s | Fusion=%s | %dx1 | Mean=%.3f m | Median=%.3f m | P90=%.3f m | P95=%.3f m\n", ...
                    distName, staSep, materialName, fusionType, antennaSizes(antIdx), ...
                    mean(distErr), medErr, p90Err, p95Err);

                [f_pos, x_pos] = ecdf(distErr);
                accuracyArray(antIdx) = accPct;
                meanDistErrArray(antIdx) = mean(distErr);
                positioningCDF{antIdx} = struct('f', f_pos, 'x', x_pos);

                hReg = figure('Color','w','Name','Position Error CDF');
                plot(x_pos, f_pos, 'LineWidth', 2); grid on;
                xlabel('Distance Error (m)');
                ylabel('CDF');
                title(sprintf('Positioning CDF | %s | Sep=%.1f | %s | %s | %dx1 | Mean=%.2f m', ...
                    distName, staSep, materialName, fusionType, antennaSizes(antIdx), mean(distErr)));
                
                regFile = sprintf('cdfpos_%s_sep%.1f_%s_%s_%dx1_%s_mean%.2fm.png', ...
                    distName, staSep, materialName, fusionType, antennaSizes(antIdx), char(chanBW), mean(distErr));
                
                exportgraphics(hReg, fullfile(outDir, regFile), 'Resolution', 300);
                close(hReg);    
          



                end
                distKey = matlab.lang.makeValidName(distName);
                matKey  = matlab.lang.makeValidName(materialName);
                fusKey  = matlab.lang.makeValidName(fusionType);
                sepKey  = matlab.lang.makeValidName(sprintf("sep_%0.1f", staSep)); % use underscore
                
                allAccuracy.(distKey).(matKey).(fusKey).(sepKey) = accuracyArray;
                allPositionError.(distKey).(matKey).(fusKey).(sepKey) = meanDistErrArray;
                allPositioningCDF.(distKey).(matKey).(fusKey).(sepKey) = positioningCDF;


            end
         end
    end
end

        % === Final Overlays for Comparison ===
        % Build a 2×A matrix of accuracies (rows = distributions, cols = antenna sizes)
        disp('Fields in allAccuracy:');
        disp(fieldnames(allAccuracy));

        A = numel(antennaSizes);
        accMat = zeros(numel(distribution), A);
        
        for d = 1:numel(distribution)
            dn = distribution{d};
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