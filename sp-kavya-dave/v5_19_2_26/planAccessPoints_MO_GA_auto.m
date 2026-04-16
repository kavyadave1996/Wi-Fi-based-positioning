

function [APsSet, paretoObj, meta] = planAccessPoints_MO_GA_auto(STAs, mapFile, materialName, paramsGA, txArraySize, K)
    % Initialize metadata
    meta = struct();
    if nargin < 6 || isempty(K), K = 10; end
    if isstring(materialName), materialName = char(materialName); end

    % 1. Calculate Area-based bounds (Logical Scaling)
    TR = stlread(mapFile); V = TR.Points;
    stlMin = min(V,[],1); stlMax = max(V,[],1);
    area_m2 = (stlMax(1)-stlMin(1)) * (stlMax(2)-stlMin(2));
    
    % 2. Setup Candidate Grid
    margin = paramsGA.margin; gridStep = paramsGA.gridStep;
    xs = (stlMin(1)+margin):gridStep:(stlMax(1)-margin);
    ys = (stlMin(2)+margin):gridStep:(stlMax(2)-margin);
    [XX,YY] = meshgrid(xs,ys); candXY = [XX(:) YY(:)];
    
    % Filter candidates to stay inside the floor plan
    k = boundary(V(:,1), V(:,2), 0.9);
    poly = polyshape(V(k,1), V(k,2), 'Simplify', true);
    in = isinterior(polybuffer(poly, -margin), candXY(:,1), candXY(:,2));
    candXY = candXY(in,:); Nc = size(candXY,1);
 

    % 3. Define Antenna Array (Applying txArraySize)
    if txArraySize(1) > 1
        antElement = phased.IsotropicAntennaElement;
        txAntenna = phased.ULA('Element', antElement, ...
            'NumElements', txArraySize(1), ...
            'ElementSpacing', 0.5 * (3e8/paramsGA.fc));
    else
        txAntenna = 'isotropic';
    end

    % 4. Precompute Rays (Ensuring Cartesian Consistency)
    for s = 1:numel(STAs)
        STAs(s).CoordinateSystem = 'cartesian';
    end

    % ---- Build STA XY coordinates (needed for GDOP objective) ----
    Ns = numel(STAs);
    staXY = zeros(Ns, 2);
    for s = 1:Ns
        p = STAs(s).AntennaPosition;
        staXY(s,:) = double(p(1:2)).';
    end

    pm = propagationModel("raytracing", ...
        "Method","sbr", ...
        "CoordinateSystem", "cartesian", ...
        "SurfaceMaterial", materialName, ...
        "MaxNumReflections", 1); % Planning uses 1 reflection for speed

    % Construct candidate positions matrix [3 x Nc]
    candX = candXY(:,1).';
    candY = candXY(:,2).';
    candZ = repmat(paramsGA.APheight, 1, Nc);
    
    candAP = txsite("cartesian", ...
        "AntennaPosition", [candX; candY; candZ], ...
        "Antenna", txAntenna, ...
        "TransmitterFrequency", paramsGA.fc, ...
        "TransmitterPower", paramsGA.TxPower_dBm);

    rays = raytrace(candAP, STAs, pm, "Map", mapFile);
    
    % Precompute coverage matrix
    cover = false(Nc, numel(STAs));
    for a = 1:Nc
        for s = 1:numel(STAs)
            if ~isempty(rays{a,s})
                [pl] = min([rays{a,s}.PathLoss]);
                rssi_val = paramsGA.TxPower_dBm - pl; 
                cover(a,s) = rssi_val >= paramsGA.RxSensitivity;
            end
        end
    end

    
    
  % ---- Derive AP-count bounds from ray-tracing cover matrix (statistical, no fixed multipliers) ----
    Kmin = 3;
    
    Ns = size(cover,2);
    Nc = size(cover,1);
    
    % Bernoulli trials over all AP-STA pairs
    nTrials = Nc * Ns;
    kSuccess = sum(cover(:));                 % number of "covered" links
    pHat = kSuccess / max(nTrials,1);
    
    % Wilson score interval for p (confidence controlled by paramsGA)
    if isfield(paramsGA,"pConf") && ~isempty(paramsGA.pConf)
        conf = paramsGA.pConf;                % example: 0.95
    else
        conf = 0.95;                          % default confidence (can be exposed as a parameter)
    end
    z = norminv(1 - (1-conf)/2);
    
    den = 1 + (z^2)/nTrials;
    center = (pHat + (z^2)/(2*nTrials)) / den;
    half = (z/den) * sqrt( (pHat*(1-pHat)/nTrials) + (z^2)/(4*nTrials^2) );
    
    pLow  = max(1e-6, center - half);
    pHigh = min(1-1e-6, center + half);
    
    % Required probability that a random STA sees at least Kmin APs
    if isfield(paramsGA,"minCoverage") && ~isempty(paramsGA.minCoverage)
        req = paramsGA.minCoverage;           % example: 0.98
    else
        req = 0.98;
    end
    
    % Helper: minimal N such that P(seen>=Kmin) >= req under Binomial(N,p)
    findN = @(pVal) find( (1 - binocdf(Kmin-1, (Kmin:Nc), pVal)) >= req, 1, "first" );
    
    idxLow  = findN(pLow);    % conservative (lower p -> more APs)
    idxHat  = findN(pHat);    % central estimate
    idxHigh = findN(pHigh);   % optimistic (higher p -> fewer APs)
    
    if isempty(idxLow),  N_cons = Nc; else, N_cons = (Kmin:Nc); N_cons = N_cons(idxLow); end
    if isempty(idxHat),  N_hat  = Nc; else, N_hat  = (Kmin:Nc); N_hat  = N_hat(idxHat);  end
    if isempty(idxHigh), N_opt  = Kmin; else, N_opt = (Kmin:Nc); N_opt = N_opt(idxHigh); end
    
    % Bounds from confidence interval
    minAP_bound = max(3, N_opt);              % optimistic lower bound
    maxAP_bound = min(Nc, N_cons);            % conservative upper bound
    
    fprintf("Auto bounds from cover (Wilson %.0f%%): pHat=%.4f [%.4f..%.4f] | req=%.3f | bounds=[%d..%d] | N_hat=%d\n", ...
        100*conf, pHat, pLow, pHigh, req, minAP_bound, maxAP_bound, N_hat);


    % 5. MO-GA Execution
    % Obj 1: Minimize coverage shortfall | Obj 2: Minimize number of APs
   fitness = @(x) apFitnessBoundedGDOP(x, cover, candXY, staXY, minAP_bound, maxAP_bound);

   opts = optimoptions("gamultiobj", ...
        "PopulationType", "bitstring", ...
        "PopulationSize", 100, ...
        "MaxGenerations", 80, ...
        "FunctionTolerance", 1e-5, ...
        "UseParallel", false, ...
        "Display","iter");

    [XPareto, FPareto] = gamultiobj(fitness, Nc, [], [], [], [], [], [], opts);

    idxKnee = pickKneePoint(FPareto);
    apCountAll = sum(XPareto > 0.5, 2);
    
    fprintf("\n--- Pareto front summary ---\n");
    fprintf("Pareto points: %d\n", size(FPareto,1));
    fprintf("KNEE | idx=%d | APs=%d | covShort=%.3f | cost=%.3f | gdop=%.3f\n", ...
    idxKnee, apCountAll(idxKnee), FPareto(idxKnee,1), FPareto(idxKnee,2), FPareto(idxKnee,3));

    
    M = min(10, size(FPareto,1));
    for ii = 1:M
        fprintf("Pareto #%2d | APs=%2d | covShort=%.3f | cost=%.3f | gdop=%.3f\n", ...
             ii, apCountAll(ii), FPareto(ii,1), FPareto(ii,2), FPareto(ii,3));

    end
    fprintf("--- end summary ---\n\n");


    % 6. Knee Selection & Metadata (Solving the solutionLabels error)
    numP = size(FPareto, 1);
    F_norm = (FPareto - min(FPareto)) ./ (max(FPareto) - min(FPareto) + 1e-6);
    distToUtopia = sqrt(sum(F_norm.^2, 2));
    [~, kneeIdx] = min(distToUtopia);
    
    % Select K diverse solutions including the knee
    selIdx = unique([kneeIdx; round(linspace(1, numP, min(K, numP)-1)')], 'stable');
    
    APsSet = cell(numel(selIdx), 1);
    labels = strings(numel(selIdx), 1); 
    labels(:) = "ParetoPoint";
    [~, kneeInSub] = min(distToUtopia(selIdx)); 
    labels(kneeInSub) = "KneeCompromise";

    % 7. Final AP Site Creation (Strict 3-by-N positioning)
    for k = 1:numel(selIdx)
        mask = XPareto(selIdx(k), :) > 0.5;
        tempXY = candXY(mask, :); 
        nSel = size(tempXY, 1);
        
        % Force explicit row-vectors to guarantee 3-by-N shape
        finalX = tempXY(:,1).';
        finalY = tempXY(:,2).';
        finalZ = repmat(paramsGA.APheight, 1, nSel);
        
        APsSet{k} = txsite("cartesian", ...
            "AntennaPosition", [finalX; finalY; finalZ], ...
            "Antenna", txAntenna, ...
            "TransmitterFrequency", paramsGA.fc, ...
            "TransmitterPower", paramsGA.TxPower_dBm);
    end

    paretoObj = FPareto(selIdx,:);
    meta.solutionLabels = labels;
    meta.paretoSize = numP;
    meta.idxChosen = selIdx;
    meta.area_m2 = area_m2;
    meta.txArrayUsed = txArraySize;
    
    fprintf("MO-GA Auto: Area=%.1f m2 | Best AP Count: %d\n", area_m2, sum(XPareto(kneeIdx,:)>0.5));
end