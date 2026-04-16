
clear; close all; clc;

rng('shuffle');

antennaSizes = [4, 2, 1];
chanBW = "CBW40";
distribution = {"uniform", "random"};

staSeparations = 0.25;  % STA spacing in meters

% === NEW: Material and Fusion Configuration ===
materials = {'concrete', 'wood', 'metal', 'glass', 'plasterboard'};  % 5 materials

fusionStrategies = {
    %'CIR_only',            % No fusion (baseline)
    % 'CIR_RSSI',           % CIR + RSSI concatenation
    %'CIR_AoA',            % CIR + Angle of Arrival
    % 'CIR_ToF',            % CIR + Time of Flight
    'CIR_RSSI_AoA_ToF'    % Full multimodal fusion
    };  % 5 fusion strategies (adjust as needed)
mapFileRaw = "layout.stl";
TR0 = stlread(mapFileRaw);
V0  = TR0.Points;

stlSpan0 = max(V0,[],1) - min(V0,[],1);
stlScale = 1;
if max(stlSpan0(1:2)) > 1000
    stlScale = 0.001;   % mm -> m
end

if stlScale ~= 1
    TRm = triangulation(TR0.ConnectivityList, V0 * stlScale);
    mapFile = "layout_meters.stl";
    stlwrite(TRm, mapFile);
else
    mapFile = mapFileRaw;
end

disp("STL footprint size [dx dy dz] = ");
disp(max(V0,[],1) - min(V0,[],1));
disp("STL bbox min = "); disp(min(V0,[],1));
disp("STL bbox max = "); disp(max(V0,[],1));
% =======================================================
resultsRows = [];   % table-like struct array accumulator
rowCount = 0;

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
                % localizationCDF = cell(1, numel(antennaSizes));
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
                if strcmp(distName, "uniform")

                    % Use current STA separation from loop
                    [APs, STAs] = dlPositioningCreateEnvironment(txArraySize, rxArraySize, staSep, "uniform");

                    %% ===== Rebuild STAs from STL footprint (covers full layout) =====
                    TR = stlread(mapFile);
                    V  = TR.Points;   % (apply *0.001 here only if STL is in mm)
                    
                    stlMin = min(V,[],1);
                    stlMax = max(V,[],1);
                    stlSpan = stlMax - stlMin;
                    stlScale = 1;
                    if max(stlSpan(1:2)) > 1000   % if footprint looks like mm
                        stlScale = 0.001;         % convert to meters
                    end
                    
                    V = V * stlScale;
                    stlMin = min(V,[],1);
                    stlMax = max(V,[],1);
                    
                    fprintf("STL scale used = %.4f | spanXY = [%.2f %.2f]\n", stlScale, stlMax(1)-stlMin(1), stlMax(2)-stlMin(2));

                    % ===== BUILD FLOOR FOOTPRINT POLYGON (ONCE) =====
                    k = boundary(V(:,1), V(:,2), 0.8);   % concave hull of floor
                    % Add 'KeepCollinearPoints', false to simplify the geometry
                    floorPoly = polyshape(V(k,1), V(k,2), 'Simplify', true);
                    % ===== SAFETY MARGIN INSIDE WALLS (avoid APs on/near boundary) =====
                    safePoly = polybuffer(floorPoly, -0.6);    % shrink by 60 cm (tune 0.3–1.0)
                    
                    % if polybuffer collapses (too aggressive), fall back
                    if safePoly.NumRegions == 0 || area(safePoly) < 1
                        warning("safePoly collapsed; using floorPoly instead. Reduce shrink.");
                        safePoly = floorPoly;
                    end
                    % ==========================================================
                    
                    margin = 0.7; % keep points slightly inside walls

                    %debugSTAstep = max(staSep, 2.0); % <-- REMOVE THIS
                    xv = (stlMin(1)+margin):staSep:(stlMax(1)-margin);
                    yv = (stlMin(2)+margin):staSep:(stlMax(2)-margin);
                                        
                    [X,Y] = meshgrid(xv, yv);
                    candXY = [X(:) Y(:)];
                    
                    % ===== CRITICAL: keep only free-space points =====
                    inside = isinterior(floorPoly, candXY(:,1), candXY(:,2));
                    candXY = candXY(inside,:);

                    % enforce additional spacing beyond staSep
                    switch staSep
                        case 0.25
                            minDist = 0.25;  % dense
                        case 0.50
                            minDist = 0.75;  % moderate (bigger than staSep)
                        case 0.70
                            minDist = 1.20;  % sparse
                        otherwise
                            minDist = staSep;
                    end
                    
                    % greedy thinning (fast enough for a few thousand points)
                    idx = randperm(size(candXY,1));
                    selected = false(size(candXY,1),1);
                    kept = [];
                    
                    for ii = idx
                        p = candXY(ii,:);
                        if isempty(kept)
                            kept = p;
                            selected(ii)=true;
                        else
                            d = sqrt(sum((kept - p).^2,2));
                            if all(d >= minDist)
                                kept = [kept; p]; %#ok<AGROW>
                                selected(ii)=true;
                            end
                        end
                    end
                    
                    candXY = candXY(selected,:);
                    fprintf("STA thinning: minDist=%.2f | kept=%d\n", minDist, size(candXY,1));

                    
                    staZ = stlMin(3) + 1.5;
                    
                    staTemplate = STAs(1);
                    STAsNew = staTemplate([]);
                    
                    for k = 1:size(candXY,1)
                        STAsNew(k) = rxsite( ...
                            "cartesian", ...
                            "AntennaPosition", [candXY(k,1); candXY(k,2); staZ], ...
                            "Antenna", staTemplate.Antenna, ...
                            "ReceiverSensitivity", staTemplate.ReceiverSensitivity);
                    end
                    
                    STAs = STAsNew;
                    
                    fprintf("Filtered STAs inside floor polygon: %d\n", numel(STAs));


                    fprintf("Rebuilt STAs over STL: %d points (%.1fx%.1f m footprint)\n", ...
                        numel(STAs), stlMax(1)-stlMin(1), stlMax(2)-stlMin(2));
%% =============================================================
                    
                else
                    % For random distribution, scale number based on separation
                    % Denser separation → more random STAs
                    baseNumSTAs = 800;
                    scaleFactor = (0.5 / staSep)^2;  % Quadratic scaling
                    numSTAs = round(baseNumSTAs * scaleFactor);
                    numSTAs = min(numSTAs, 800);  % Cap at 5000 for computational reasons
                    
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
                    paramsGA.TxPower_dBm = 30;                        % fallback (matches your code)
                end
                
                % --- map geometry / candidate grid derived from STA extents (automatic) ---
                paramsGA.margin     = 0.7;     % used to enlarge candidate area around STA cloud
                paramsGA.gridStep   = 1.5;     % candidate spacing (tradeoff speed vs quality)
                paramsGA.APheight   = 3;     % meters
                
                % --- ray-tracing settings for AP planning ---
                paramsGA.maxReflections = 5;
                
                % --- coverage model parameters (automatic decision still, but fixed physics knobs) ---
                paramsGA.RxSensitivity  = -75;    % dBm threshold for -covered" (adjust if needed globally)
                paramsGA.minCoverage    = 0.98;   % required coverage ratio
                
                % --- spacing constraint to avoid AP clustering ---
                paramsGA.dMin           = 3.0;    % meters
                
                % --- Multi-objective decision output count (AUTOMATIC choices will be returned) ---
                K = 4;   % internally choose 3 4best” Pareto points: max-coverage, min-cost, knee

               % Calculate area for logical scaling inside the planner
                staXY = reshape([STAs.AntennaPosition],3,[])';
                area_m2 = (max(staXY(:,1)) - min(staXY(:,1))) * (max(staXY(:,2)) - min(staXY(:,2)));
                fprintf("STA bbox: X[%.2f %.2f] Y[%.2f %.2f] | Area: %.1f m2\n", ...
                    min(staXY(:,1)), max(staXY(:,1)), min(staXY(:,2)), max(staXY(:,2)), area_m2);

                % === THE MISSING CALL: This creates paretoMeta, APsSet, and paretoObj ===
                [APsSet, paretoObj, paretoMeta] = planAccessPoints_MO_GA_auto( ...
                     STAs, mapFile, materialName, paramsGA, txArraySize, 10);
                
                % Now useIdx will work because paretoMeta finally exists
                useIdx = find(paretoMeta.solutionLabels == "KneeCompromise", 1);
                if isempty(useIdx), useIdx = 1; end
                
                APs = APsSet{useIdx};
                fprintf("Selected Knee solution with %d APs.\n", numel(APs));

                apXY = reshape([APs.AntennaPosition],3,[])';
                apXY = apXY(:,1:2);
                
                % Floor centroid (of your safe polygon)
                [cx, cy] = centroid(safePoly);
                
                % AP centroid
                apC = mean(apXY,1);
                
                fprintf("Floor centroid: [%.2f %.2f] | AP centroid: [%.2f %.2f]\n", cx, cy, apC(1), apC(2));
                
                % How imbalanced are APs in quadrants around the floor centroid?
                q1 = sum(apXY(:,1)>=cx & apXY(:,2)>=cy);
                q2 = sum(apXY(:,1)< cx & apXY(:,2)>=cy);
                q3 = sum(apXY(:,1)< cx & apXY(:,2)< cy);
                q4 = sum(apXY(:,1)>=cx & apXY(:,2)< cy);
                fprintf("AP quadrant counts (around floor centroid): Q1=%d Q2=%d Q3=%d Q4=%d (total=%d)\n", q1,q2,q3,q4,numel(APs));
                
                % Pairwise spacing stats (cluster indicator)
                D = pdist(apXY);
                fprintf("AP spacing: min=%.2f m | median=%.2f m | max=%.2f m\n", min(D), median(D), max(D));
                
                % Plot
                figure('Color','w'); hold on; axis equal; grid on;
                plot(safePoly,'FaceColor',[0.95 0.95 0.95],'EdgeColor',[0.2 0.2 0.2]);
                plot(apXY(:,1), apXY(:,2), 'ro', 'MarkerSize', 10, 'LineWidth', 2);
                plot(cx, cy, 'kx', 'MarkerSize', 14, 'LineWidth', 2);
                plot(apC(1), apC(2), 'bx', 'MarkerSize', 14, 'LineWidth', 2);
                legend('safePoly','APs','floor centroid','AP centroid','Location','bestoutside');
                title("AP placement spread check");

                % ===== VERIFY APs ARE INSIDE FLOOR =====
                apXYZ = reshape([APs.AntennaPosition],3,[])';
                insideAP = isinterior(safePoly, apXYZ(:,1), apXYZ(:,2));
                
                if any(~insideAP)
                    warning("Some APs are outside floor polygon — raytrace will fail");
                end

     
               % fprintf("MAIN picked: %s (useIdx=%d) | APs=%d | txArray=%dx%d\n", ...
                     %paretoMeta.solutionLabels(useIdx), useIdx, numel(APs), txArraySize(1), txArraySize(2));
                
                    % then run raytrace/dataset/training as usual...
    
                %fprintf("MO-GA selected %d candidate solutions; using solution #%d with %d APs.\n", ...
                    %numel(APsSet), useIdx, numel(APs));
                
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
                if strcmp(distName, "uniform")

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
                    % Show APs (red) and STAs (blue)
                    show(APs); % Show the selected APs (red)
                    show(STAs, "ShowAntennaHeight", false, "IconSize", [16 16]); % Show STAs (blue)                  
                end

                % ---- FIXED HEIGHTS ----
                floorZ = stlMin(3);
                staZ   = floorZ + 1.2;   % 1.2m
                apZ    = floorZ + 2.2;   % 2.2m (below ceiling)

                
                % Force all STAs to staZ
                for k = 1:numel(STAs)
                    p = STAs(k).AntennaPosition;
                    STAs(k).AntennaPosition = [p(1); p(2); staZ];
                end
                
                % Force all APs to apZ
                for a = 1:numel(APs)
                    p = APs(a).AntennaPosition;
                    APs(a).AntennaPosition = [p(1); p(2); apZ];
                end
                 % Propagation Model for Ray Tracing

                 pm= propagationModel("raytracing", ...
                    "CoordinateSystem", "cartesian", ...
                    "Method", "sbr", ...
                    "AngularSeparation", "medium", ...                    
                    "SurfaceMaterial", materialName, ...           % use your loop material (NOT fixed concrete)
                    "MaxNumReflections", paramsGA.maxReflections);

                 apXYZ = reshape([APs.AntennaPosition],3,[])';
                staXYZ = reshape([STAs.AntennaPosition],3,[])';
                
                fprintf("Z check: floorZ=%.2f | STA z range [%.2f %.2f] | AP z range [%.2f %.2f]\n", ...
                    floorZ, min(staXYZ(:,3)), max(staXYZ(:,3)), min(apXYZ(:,3)), max(apXYZ(:,3)));

                
                rays = raytrace(APs, STAs, pm, "Map", mapFile);


                nAP  = size(rays,1);
                nSTA = size(rays,2);
                
                apCountPerSTA = zeros(nSTA,1);
                for s = 1:nSTA
                    apCountPerSTA(s) = nnz(~cellfun(@isempty, rays(:,s)));
                end
                
                pct3 = mean(apCountPerSTA >= 3) * 100;
                pct4 = mean(apCountPerSTA >= 4) * 100;
                fprintf("STAs with >=3 APs: %.1f%% | >=4 APs: %.1f%%\n", pct3, pct4);
                
                % ===== Build PL matrix from rays (AP x STA) =====
                numAP  = numel(APs);
                numSTA = numel(STAs);
                PL = nan(nAP, nSTA);
                for a = 1:nAP
                    for s = 1:nSTA
                        rr = rays{a,s};
                        if isempty(rr), continue; end
                        PL(a,s) = min([rr.PathLoss]);
                    end
                end
                
                PLfilled = PL;
                PLfilled(isnan(PLfilled)) = 300;

                connMask = (PLfilled < 300);  % has at least one ray
                connRate = mean(connMask(:)) * 100;
                fprintf("Connection rate (has ray): %.2f%%\n", connRate);
                
                thrMask  = (paramsGA.TxPower_dBm - PLfilled) >= paramsGA.RxSensitivity;
                thrRate  = mean(thrMask(:)) * 100;
                fprintf("Connection rate (RSSI>=thr): %.2f%%\n", thrRate);


                % ---- After PLfilled is built ----

                apCountPerSTA_thr = sum( ...
                    (paramsGA.TxPower_dBm - PLfilled) >= paramsGA.RxSensitivity, 1);
                
                fprintf("THR STAs with >=1 AP: %.1f%%\n", ...
                    mean(apCountPerSTA_thr>=1)*100);
                
                fprintf("THR STAs with >=3 APs: %.1f%%\n", ...
                    mean(apCountPerSTA_thr>=3)*100);
                
                fprintf("THR STAs with >=4 APs: %.1f%%\n", ...
                    mean(apCountPerSTA_thr>=4)*100);


                blindSTAs = sum(PLfilled < 300, 1) == 0;   % no AP link at all
                fprintf("Blind STAs (no rays from any AP): %d / %d\n", nnz(blindSTAs), numSTA);

                
                % pick STA that has the MOST AP visibility (best debug point)
                [~, targetSTA] = max(apCountPerSTA);
                
                lossPerAP_dB  = PLfilled(:, targetSTA);
                rssiPerAP_dBm = paramsGA.TxPower_dBm - lossPerAP_dB;
                
                disp(table((1:nAP)', lossPerAP_dB, rssiPerAP_dBm, ...
                    'VariableNames', {'AP','PathLoss_dB','RSSI_dBm'}));
                % ===============================================

                 % Check ray tracing quality - LOW COVERAGE = LOW ACCURACY

                 validConnections = sum(~cellfun(@isempty, rays(:)));

                 fprintf('Valid AP-STA connections: %d/%d (%.1f%%)\n', ...
                 validConnections, numel(rays), 100*validConnections/numel(rays));

                 % 3. AFTER RAY TRACING (after raytrace)

                 fprintf('\n=== RAY TRACING INFO ===\n');

                 fprintf('Ray matrix size: %dx%d\n', size(rays,1), size(rays,2));

                 totalRays = 0;

                 emptyConnections = 0;

                 for ii = 1:size(rays,1)

                     for jj = 1:size(rays,2)

                             if ~isempty(rays{ii,jj})

                             totalRays = totalRays + 1;

                             else

                             emptyConnections = emptyConnections + 1;

                             end

                      end

                  end

                 fprintf('Total valid ray paths: %d\n', totalRays);

                 fprintf('Empty connections: %d\n', emptyConnections);

                 fprintf('Connection rate: %.2f%%\n', 100*totalRays/(totalRays+emptyConnections));

                 % Pick a target STA to inspect rays (middle one)

                 targetSTA = ceil(numel(STAs)/2);

                 hide(STAs);

                 show(STAs(targetSTA),'IconSize',[32 32]); % highlight target STA

                 % Plot rays from ALL APs that actually have paths to this STA

                 if iscell(rays) && size(rays,2) >= targetSTA

                     hasRayFromAP = ~cellfun(@isempty, rays(:,targetSTA));

                         if any(hasRayFromAP)

                         plot([rays{hasRayFromAP,targetSTA}], 'ColorLimits', [50 95]);

                         else

                         warning('No rays found to target STA from any AP.');

                         end

                 end
                
                arrayGain_dB = 10*log10(prod(txArraySize));   % same definition as planner
                 NsFull = numel(STAs);
                covered = false(NsFull,1);
                
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

                                % ===== Pick a target STA that actually has rays / is covered =====
                idxCovered = find(covered);
                if isempty(idxCovered)
                    warning("No covered STAs at all — cannot plot rays.");
                    targetSTA = 1;
                else
                    targetSTA = idxCovered(randi(numel(idxCovered)));  % pick a random covered STA
                end

                fprintf("DEBUG: targetSTA=%d | covered=%d\n", targetSTA, covered(targetSTA));

                % Quick sanity check (optional)
                if isempty(rays)
                    warning('Ray tracer returned empty. Check map units/coordinates.');
                end

                cfg = heRangingConfig('ChannelBandwidth',chanBW, ...
                    "NumTransmitAntennas", prod(txArraySize), ...
                    "SecureHELTF", false);
                user = heRangingUser;
                user.NumSpaceTimeStreams = prod(txArraySize);
                cfg.User = {user};
                txWaveform = single(heRangingWaveformGenerator(cfg));
                snrs = 0:2:40;

                % Generate features and labels from dataset
                [features, labels] = dlPositioningGenerateDataSet(rays, STAs, APs, cfg, snrs);

                % ===== Compute sample2sta immediately after dataset generation =====
                staPos = reshape([STAs.AntennaPosition],3,[])';
                posLabels = double(labels.position.');    % N x 3
                Dpos = pdist2(posLabels, staPos);         % N x numSTA
                [~, sample2sta] = min(Dpos, [], 2);       % N x 1

                
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
                
                newFeatures = features + noiseLevel * randn(size(features), 'like', features);
                features = newFeatures;


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
                        txP = paramsGA.TxPower_dBm;
                        rssi_sta(s) = txP - bestPL;      % ✅ CORRECT RSSI
                        tof_sta(s)  = bestToF;
                        aoa_sta(s,:) = bestAoA(:).';
                    end
                end

                
                % ---- 4) Build per-sample 4D tensors (Optimized with Normalization) ----

                % FIRST: Normalize the raw STA data to a [0, 1] range
                % This ensures ToF (tiny numbers) and AoA (big numbers) have equal weight
                rssi_norm = (rssi_sta - (-100)) / (0 - (-100)); % Map -100dBm..0dBm to 0..1
                aoa_norm  = (aoa_sta + 180) / 360;              % Map -180..180 degrees to 0..1
                tof_norm  = tof_sta / 500e-9;                   % Scale typical indoor delay (max 500ns) to 0..1
                
                % Pre-allocate tensors
                rssi4D = zeros(1,1,1,numSamples,'like',features);
                tof4D  = zeros(1,1,1,numSamples,'like',features);
                aoa4D  = zeros(1,1,2,numSamples,'like',features); 
                
                for n = 1:numSamples
                    s = sample2sta(n);
                    % Populate with normalized values
                    rssi4D(1,1,1,n) = rssi_norm(s);
                    tof4D(1,1,1,n)  = tof_norm(s);
                    aoa4D(1,1,1,n)  = aoa_norm(s,1); % Azimuth
                    aoa4D(1,1,2,n)  = aoa_norm(s,2); % Elevation
                end
                
                % Replace NaNs with 0 to prevent training "Exploding Gradients"
                rssi4D(isnan(rssi4D)) = 0;
                tof4D(isnan(tof4D))   = 0;
                aoa4D(isnan(aoa4D))   = 0;
                
                % ---- 5) Apply fusion strategy ----
                fprintf("          Applying fusion: %s\n", fusionType);
                [H, W, ~, ~] = size(features);
                
                switch fusionType
                    case 'CIR_only'
                        % Baseline: No extra channels added
                        fusedFeatures = features;
                
                    case 'CIR_RSSI_AoA_ToF'
                        % Full Multi-Modal: Add 4 normalized channels to the CIR
                        rssiExp = repmat(rssi4D, [H, W, 1, 1]);      
                        aoaExp  = repmat(aoa4D,  [H, W, 1, 1]);      
                        tofExp  = repmat(tof4D,  [H, W, 1, 1]);      
                        
                        % This results in an 11-channel tensor (CIR + 1 RSSI + 2 AoA + 1 ToF)
                        fusedFeatures = cat(3, features, rssiExp, aoaExp, tofExp); 
                
                    otherwise
                        error('Unknown fusion strategy: %s. Use CIR_only or CIR_RSSI_AoA_ToF.', fusionType);
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

                %% ========= OVERRIDE labels.class using your 8 labeled floor-plan zones ========
                % ---------- 1) Load your 8 zone polygons (STL XY coordinates) ----------
                load("zones_STLXY.mat","zones");
                zoneNames = fieldnames(zones);
                
                % ---------- 2) Get STA XY (must be BEFORE using staXY) ----------
                staXYZ = reshape([STAs.AntennaPosition],3,[])';
                staXY  = staXYZ(:,1:2);
                
                % ---------- 3) Debug ranges ----------
                fprintf("STA XY range: X[%.2f %.2f], Y[%.2f %.2f]\n", ...
                    min(staXY(:,1)), max(staXY(:,1)), min(staXY(:,2)), max(staXY(:,2)));
                
                for z = 1:numel(zoneNames)
                    P = zones.(zoneNames{z});
                    fprintf("Zone %s range: X[%.2f %.2f], Y[%.2f %.2f]\n", zoneNames{z}, ...
                        min(P(:,1)), max(P(:,1)), min(P(:,2)), max(P(:,2)));
                end
                
                % ---------- 4) Assign each STA to a zone ----------
                staZone = strings(size(staXY,1),1);
                staZone(:) = "0";
                
                for z = 1:numel(zoneNames)
                    name = zoneNames{z};
                    P = zones.(name); % Nx2
                    inside = inpolygon(staXY(:,1), staXY(:,2), P(:,1), P(:,2));
                    staZone(inside) = string(name);
                end
                
                % ---------- 5) Debug counts AFTER assignment ----------
                fprintf("Zone assignment counts (AFTER):\n");
                disp(groupcounts(categorical(staZone)));
                
                fprintf("How many STAs unlabeled (zone 0)? %d / %d\n", nnz(staZone=="0"), numel(staZone));
                
                % ---------- 6) Debug plot STAs vs Zones ----------
                figure; hold on; axis equal; grid on;
                plot(staXY(:,1), staXY(:,2), 'b.', 'DisplayName','STAs');
                
                for z = 1:numel(zoneNames)
                    P = zones.(zoneNames{z});
                    plot(P(:,1), P(:,2), 'r-', 'LineWidth', 2, 'DisplayName', zoneNames{z});
                end
                legend('Location','bestoutside');
                title("DEBUG: STAs vs Zones");
                
                % ---------- 7) Map each sample -> STA -> zone ----------
                sampleZone  = staZone(sample2sta);
                labels.class = categorical(sampleZone);
                
                % ---------- 8) Drop unlabeled samples ----------
                keepIdx = labels.class ~= categorical("0");
                
                if nnz(keepIdx) == 0
                    error("All samples got class '0' after zone assignment. Fix zone polygons / coordinate system. Nothing left to train.");
                end
                
                features        = features(:,:,:,keepIdx);
                labels.class    = labels.class(keepIdx);
                labels.position = labels.position(:,keepIdx);
                
                labels.class = removecats(labels.class);
                
                disp("DEBUG: New zone classes:");
                disp(categories(labels.class));
                disp("DEBUG: New zone counts:");
                disp(countcats(labels.class));

               % === START OF MEMORY-SAFE REPLACEMENT ===
                
                % 1. Convert to SINGLE precision immediately (Cuts RAM usage by 50%)
                % This drops your 33.26 GB tensor to ~16.63 GB.
                features = single(features); 

                % 2. Count and balance (Capped at 5,000 samples per class for 8 zones)
                classes = categories(labels.class);
                counts = countcats(labels.class);

                max_samples_per_class = 5000; 
                target_count = min(max_samples_per_class, round(median(counts)));

                balanced_idxs = [];
                for i = 1:length(classes)
                    idx = find(labels.class == classes{i});
                    n_samples = length(idx);
                    idx = idx(:); % Force column vector

                    if n_samples >= target_count
                        % Undersample large classes to stay within RAM limits
                        idx = idx(randperm(n_samples, target_count));
                    else
                        % Oversample small classes using replacement
                        idx_original = idx;
                        while length(idx) < target_count
                            n_needed = min(n_samples, target_count - length(idx));
                            new_idx = idx_original(randperm(n_samples, n_needed));
                            idx = [idx; new_idx(:)]; 
                        end
                        idx = idx(1:target_count); % Trim to exact target
                    end
                    balanced_idxs = [balanced_idxs; idx];
                end

                disp('Class distribution after balancing:');
                disp(countcats(labels.class(balanced_idxs)));

                % 3. The "Clear-as-you-go" Technique
                % Subsampling a large array creates a temporary copy. 
                % We clear the original immediately to free up the 16GB.
                temp_features = features(:,:,:,balanced_idxs);
                clear features; 
                features = temp_features; 
                clear temp_features; 

                % Sync the labels with the new indices
                labels.class = labels.class(balanced_idxs);
                labels.position = labels.position(:, balanced_idxs);

                % Ensure correct shapes for the ResNet training
                labels.class = labels.class(:)';     
                labels.position = labels.position(:, :); 

                % === END OF MEMORY-SAFE REPLACEMENT ===
               % ==== DATASET AUGMENTATION: FEATURES + LABELS TOGETHER ====
                numOriginal = size(features, 4);     % current number of samples
                augFactor  = 2;                      % how many times to replicate (try 2 or 3 first)
                numSamples = numOriginal * augFactor;
                
                [H,W,C,~] = size(features);
                
                features_aug = zeros(H, W, C, numSamples, 'like', features);
                labels_aug_class = categorical(strings(numSamples,1), categories(labels.class));  % preallocate safely
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

                % % --- Split by STA (NOT random samples) ---   using this
                % it is giving 6 classess for sta separation .7 and .5 
                % valFrac = 0.2;
                % permSTA = randperm(numSTA);
                % nValSTA = max(1, round(valFrac*numSTA));
                % 
                % valSTA   = permSTA(1:nValSTA);
                % trainSTA = permSTA(nValSTA+1:end);
                % 
                % isVal    = ismember(sample2sta, valSTA);
                % trainIdx = find(~isVal);
                % valIdx   = find(isVal);
               
                % ===== SAFE SPLIT: stratified by class, guarantees TRAIN is non-empty =====
                valFrac  = 0.2;
                trainIdx = [];
                valIdx   = [];
                
                labels.class = removecats(labels.class);
                uniqueClasses = categories(labels.class);
                
                for i = 1:numel(uniqueClasses)
                    thisClassIdx = find(labels.class == uniqueClasses{i});
                    if isempty(thisClassIdx), continue; end
                
                    stasInClass = unique(sample2sta(thisClassIdx));
                    nSTA = numel(stasInClass);
                
                    if nSTA >= 2
                        % --- split by STA ---
                        permSTA = stasInClass(randperm(nSTA));
                        nValSTA = max(1, round(valFrac*nSTA));
                        nValSTA = min(nValSTA, nSTA-1);   % ALWAYS leave >=1 STA for TRAIN
                
                        valSTAs   = permSTA(1:nValSTA);
                        trainSTAs = permSTA(nValSTA+1:end);
                
                        thisValIdx   = thisClassIdx(ismember(sample2sta(thisClassIdx), valSTAs));
                        thisTrainIdx = thisClassIdx(ismember(sample2sta(thisClassIdx), trainSTAs));
                
                    else
                        % --- only 1 STA exists -> split by samples ---
                        n = numel(thisClassIdx);
                        perm = thisClassIdx(randperm(n));
                        nVal = max(1, round(valFrac*n));
                        nVal = min(nVal, n-1);            % ALWAYS leave >=1 sample for TRAIN
                
                        thisValIdx   = perm(1:nVal);
                        thisTrainIdx = perm(nVal+1:end);
                    end
                
                    trainIdx = [trainIdx; thisTrainIdx(:)];
                    valIdx   = [valIdx;   thisValIdx(:)];
                end
                
                trainIdx = trainIdx(:);
                valIdx   = valIdx(:);
                
                fprintf("Split: Train=%d | Val=%d | Total=%d\n", numel(trainIdx), numel(valIdx), numSamplesFinal);
                
                assert(~isempty(trainIdx), "TRAIN is empty after split — cannot train.");
                assert(~isempty(valIdx),   "VAL is empty after split — cannot validate.");


                % 1. Extract raw subsets
                trainX = features(:,:,:,trainIdx);
                trainY_class = labels.class(trainIdx);
                trainY_reg = labels.position(:,trainIdx).';
                
                valX = features(:,:,:,valIdx);
                valY_class = labels.class(valIdx);
                valY_reg = labels.position(:,valIdx).';
                
                % 2. Synchronize Categories (Crucial Step)
                % This ensures validation labels recognize ALL classes found in training
                allKnownClasses = categories(removecats(labels.class));
                training.Y.classification = categorical(trainY_class, allKnownClasses);
                validation.Y.classification = categorical(valY_class, allKnownClasses);
                
                % 3. Assign other fields
                training.X = trainX;
                training.Y.regression = trainY_reg;
                validation.X = valX;
                validation.Y.regression = valY_reg;
                          
                fprintf("Split-by-STA: Train=%d | Val=%d | Total=%d\n", ...
                    numel(trainIdx), numel(valIdx), numSamplesFinal);
                
                % Safety check
                assert(max([trainIdx; valIdx]) <= numSamplesFinal, ...
                       "Index exceeds feature count!");
                % =====================================================================


                % [training,validation] = dlPositioningSplitDataSet(features,labels,0.2);

                % ======= APPLY STA-GROUP SPLIT (instead of random split) =======
                % training.X = features(:,:,:,trainIdx);
                % training.Y.classification = labels.class(trainIdx);
                % training.Y.regression     = labels.position(:,trainIdx).';   % N x 3
                % 
                % validation.X = features(:,:,:,valIdx);
                % validation.Y.classification = labels.class(valIdx);
                % validation.Y.regression     = labels.position(:,valIdx).';   % N x 3
                % 
                % training.Y.classification    = removecats(training.Y.classification);
                % validation.Y.classification  = categorical(validation.Y.classification, categories(training.Y.classification));

                % Ensure there are no undefined categories in validation
                if any(isundefined(validation.Y.classification))
                    warning('Validation labels contain undefined categories. This will be handled.');
                end

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

                %% ===== VISUALIZE PREDICTED CLASSES ON FLOOR PLAN =====

                % --- True XY positions of validation samples ---
                trueXY = validation.Y.regression(:,1:2);   % Nx2
                
                % --- Predicted classes ---
                predClass = categorical(YPred);
                
                figure('Color','w'); hold on; axis equal; grid on;
                
                % --- Optional: plot STL floor footprint (2D) ---
                try
                    plot(floorPoly, ...
                        'FaceColor',[0.95 0.95 0.95], ...
                        'EdgeColor',[0.2 0.2 0.2]);
                catch
                    warning("floorPoly not found — plotting points only");
                end
                
                % --- Scatter true positions, colored by predicted class ---
                gscatter(trueXY(:,1), trueXY(:,2), predClass);
                
                xlabel('X [m]');
                ylabel('Y [m]');
                title('CNN Location Prediction (Predicted Class)');
                
                % --- Overlay zone polygons ---
                load("zones_STLXY.mat","zones");
                zoneNames = fieldnames(zones);
                
                for i = 1:numel(zoneNames)
                    P = zones.(zoneNames{i});
                    plot(P(:,1), P(:,2), 'k-', 'LineWidth', 2);
                    text(mean(P(:,1)), mean(P(:,2)), zoneNames{i}, ...
                        'FontWeight','bold', ...
                        'HorizontalAlignment','center');
                end
                
                legend('Location','eastoutside');

                %% ===== END VISUALIZATION =====

                
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

                % Visual map plot of predicted classes over true STA positions
                dlPositioningPlotResults(mapFile, validation.Y, yPred, "localization");

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
                % 
                % % 10) Localization CDF (0 = correct, 1 = wrong) based on filtered labels
                % locErrorVec = (yPred ~= yTrue);
                % [f_loc, x_loc] = ecdf(double(locErrorVec));
                % localizationCDF{antIdx} = struct('f', f_loc, 'x', x_loc);



                %% ========= RESNET-18 BASED POSITION REGRESSION =========
                fprintf('Training regression network with ResNet-18...\n');

                % 1. Load and Adapt ResNet-18 Graph for Regression
                netResReg = resnet18;
                lgraphReg = layerGraph(netResReg);

                % 2. Adapt Input Layer (same as classification)
                inputSize = size(training.X, 1:3);
                newInputReg = imageInputLayer(inputSize, ...
                    'Name', 'input_reg', ...
                    'Normalization', 'none');
                lgraphReg = replaceLayer(lgraphReg, lgraphReg.Layers(1).Name, newInputReg);

                % 3. Adapt First Convolution Layer for C channels (e.g., 10 channels)
                Ctarget = inputSize(3);
                origConv = lgraphReg.Layers(2);
                w = origConv.Weights;
                cOrig = size(w, 3);

                % Replicate channels and rescale energy
                repFactor = ceil(Ctarget / cOrig);
                wRep = repmat(w, 1, 1, repFactor, 1);
                wNew = wRep(:, :, 1:Ctarget, :) * (cOrig / Ctarget);

                newConvReg = convolution2dLayer(origConv.FilterSize, origConv.NumFilters, ...
                    'Stride', origConv.Stride, ...
                    'Padding', origConv.PaddingSize, ...
                    'Name', origConv.Name);
                newConvReg.Weights = wNew;
                newConvReg.Bias = origConv.Bias;
                lgraphReg = replaceLayer(lgraphReg, origConv.Name, newConvReg);

                % 4. Replace the Classification Head with a Regression Head
                % We remove the final FC, Softmax, and Classification layers
                lgraphReg = removeLayers(lgraphReg, {'fc1000', 'prob', 'ClassificationLayer_predictions'});

                % Add a new FC layer with 3 outputs [x, y, z] and a regression layer
                regHead = [
                    fullyConnectedLayer(3, 'Name', 'fc_regression_out')
                    regressionLayer('Name', 'regout')
                    ];

                lgraphReg = addLayers(lgraphReg, regHead);
                lgraphReg = connectLayers(lgraphReg, 'pool5', 'fc_regression_out');

                % 5. Training Options for Regression
                trainY = single(training.Y.regression);
                valY = single(validation.Y.regression);

                optsReg = trainingOptions("adam", ...
                    "MiniBatchSize", 64, ...
                    "MaxEpochs", 15, ... % Increased epochs for ResNet convergence
                    "InitialLearnRate", 1e-4, ... % Lower learning rate for fine-tuning
                    "Shuffle", "every-epoch", ...
                    "ValidationData", {validation.X, valY}, ...
                    "Verbose", true, ...
                    "ExecutionEnvironment", "auto");

                % 6. Train the ResNet-18 Regressor
                % Using trainNetwork to match the categorical workflow
                netPos = trainNetwork(training.X, trainY, lgraphReg, optsReg);
                
                % ---------- Evaluate positioning ----------
                YPredPos = predict(netPos, validation.X);  % N×3
                
                trueLocs = valY;      % N×3
                predLocs = YPredPos;  % N×3
                
                distErr = sqrt(sum((trueLocs - predLocs).^2, 2));  % N×1

                meanErr = mean(distErr);
                p50Err  = prctile(distErr, 50);   % same as median
                p90Err  = prctile(distErr, 90);
                p95Err  = prctile(distErr, 95);
                
                fprintf("REGRESSION | %s | Sep=%.2f | Mat=%s | Fusion=%s | %dx1 | Mean=%.3f m | P50=%.3f m | P90=%.3f m | P95=%.3f m\n", ...
                    distName, staSep, materialName, fusionType, antennaSizes(antIdx), ...
                    meanErr, p50Err, p90Err, p95Err);


                rowCount = rowCount + 1;

                resultsRows(rowCount).BW        = char(chanBW);
                resultsRows(rowCount).Dist      = char(distName);
                resultsRows(rowCount).Array     = sprintf("%dx1", antennaSizes(antIdx));
                resultsRows(rowCount).Sep       = staSep;
                resultsRows(rowCount).Material  = char(materialName);
                resultsRows(rowCount).Fusion    = char(fusionType);
                
                resultsRows(rowCount).AccPct    = accPct;      % classification accuracy %
                resultsRows(rowCount).Mean_m    = meanErr;
                resultsRows(rowCount).P50_m     = p50Err;
                resultsRows(rowCount).P90_m     = p90Err;
                resultsRows(rowCount).P95_m     = p95Err;
                resultsRows(rowCount).NSamples  = numel(distErr);


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

                % 
                % distKey = matlab.lang.makeValidName(distName);
                % matKey  = matlab.lang.makeValidName(materialName);
                % fusKey  = matlab.lang.makeValidName(fusionType);
                % sepKey  = matlab.lang.makeValidName(sprintf("sep_%0.1f", staSep)); % use underscore
                
              % Convert the floating-point staSep value to a valid string for field name
                validSep = strrep(sprintf('sep%.1f', staSep), '.', '_');  % Replaces '.' with '_'
                
                % Store the accuracy and positioning data using valid field names
                allAccuracy.(distName).(materialName).(fusionType).(validSep) = accuracyArray;
                disp(allAccuracy.(distName).(materialName).(fusionType).(validSep));
                
                allPositioningCDF.(distName).(materialName).(fusionType).(validSep) = positioningCDF;
                disp(allPositioningCDF.(distName).(materialName).(fusionType).(validSep));



                end
            end
        end
    end
end

        % === Final Overlays for Comparison ===
        fusName = "CIR_RSSI_AoA_ToF";
        materials = fieldnames(allAccuracy.uniform);
        distributions = fieldnames(allAccuracy);
        
        separations = {};
        for s = [0.7 0.5 0.25]
            separations{end+1} = strrep(sprintf("sep%.1f", s), ".", "_");
        end
        
        results = struct();
        
        for d = 1:numel(distributions)
            dist = distributions{d};
            for m = 1:numel(materials)
                mat = materials{m};
                for sp = 1:numel(separations)
                    sep = separations{sp};
        
                    if isfield(allAccuracy.(dist).(mat).(fusName), sep)
                        results.(dist).(mat).(sep) = ...
                            allAccuracy.(dist).(mat).(fusName).(sep);
                    end
                end
            end
        end

         A = numel(antennaSizes);
        accOverall = zeros(numel(distribution), A);
        
        for d = 1:numel(distribution)
            dist = distribution{d};
            accStack = [];
        
            for m = 1:numel(materials)
                mat = materials{m};
                for sp = 1:numel(separations)
                    sep = separations{sp};
                    if isfield(results.(dist).(mat), sep)
                        accStack = [accStack; results.(dist).(mat).(sep)];
                    end
                end
            end
        
            accOverall(d,:) = mean(accStack,1);  % average across all mats & seps
        end


% Plot Localization accuracy bar chart
hBar = figure('Name', 'Localization accuracy — bar', 'Color', 'w');
bar(accOverall', 'grouped'); grid on;
xlabel('Antenna size'); ylabel('Accuracy (%)');
set(gca, 'XTickLabel', strcat(string(antennaSizes), 'x1')); % 4x1, 2x1, 1x1 etc.
legend(distribution, 'Location', 'southoutside', 'Orientation', 'horizontal');
title('Localization accuracy by antenna and distribution');
exportgraphics(hBar, 'summary_localization_bar.png', 'Resolution', 300);
close(hBar);
 
% Plot CDF for Positioning Error Comparison
figPos = figure('Name', 'CDF - Positioning Error Comparison');
hold on;

for d = 1:numel(distribution)
    distName = distribution{d};
    for i = 1:numel(antennaSizes)
        % Ensure the data exists before plotting
        if isfield(allPositioningCDF, distName) && isfield(allPositioningCDF.(distName), num2str(antennaSizes(i)))
            plot(allPositioningCDF.(distName)(i).x, allPositioningCDF.(distName)(i).f, ...
                'LineWidth', 2, 'Color', [0.00, 0.45, 0.74], ...
                'DisplayName', sprintf('%s - %dx1', distName, antennaSizes(i)));
        else
            disp('No positioning data found for this configuration.');
        end
    end
end

xlabel('Distance Error (m)'); ylabel('CDF'); legend; grid on;
title('Final CDF - Positioning Error Comparison');
saveas(figPos, 'Final_CDF_Positioning_Comparison.jpeg');

% --- BANDWIDTH COMPARISON LOGIC ---
bw_list = ["CBW40", "CBW80", "CBW160"];
res_table = struct();

% Loop through results and extract Mean RMSE for each Bandwidth
for b = 1:numel(bw_list)
    thisBW = bw_list(b);
    % Find all files matching this bandwidth in your results folder
    files = dir(fullfile(outDir, sprintf("*_%s_*_mean*.png", thisBW)));
    
    % Extract the mean value from the filenames (e.g., mean0.12m.png)
    means = zeros(numel(files), 1);
    for f = 1:numel(files)
        valStr = regexp(files(f).name, 'mean(\d+\.\d+)m', 'tokens');
        if ~isempty(valStr)
            means(f) = str2double(valStr{1}{1});
        end
    end
    res_table.(char(thisBW)) = mean(means(means > 0)); % Average RMSE for this BW
end


T = struct2table(resultsRows);
writetable(T, fullfile(outDir, "results_summary.csv"));
writetable(T, fullfile(outDir, "results_summary.xlsx"));

disp("Saved results table:");
disp(head(T));

Tfull = T;  % keep original
Tfull.Mean_m = double(Tfull.Mean_m);

figure('Color','w'); 
boxchart(categorical(Tfull.BW), Tfull.Mean_m);
ylabel("Position error (m)"); grid on;
title("BW impact on positioning error (distribution over all runs)");
exportgraphics(gcf, fullfile(outDir, "BW_boxplot_mean.png"), 'Resolution', 300);

figure('Color','w');
boxchart(categorical(Tfull.Fusion), Tfull.P90_m);
ylabel("P90 error (m)"); grid on;
title("Fusion impact using P90 (tail accuracy)");
exportgraphics(gcf, fullfile(outDir, "Fusion_boxplot_p90.png"), 'Resolution', 300);

figure('Color','w');
boxchart(categorical(Tfull.Array), Tfull.Mean_m);
ylabel("Mean error (m)"); grid on;
title("Array size impact on positioning mean error");
exportgraphics(gcf, fullfile(outDir, "Array_boxplot_mean.png"), 'Resolution', 300);


