function [APsSet, paretoObj, meta] = planAccessPoints_MO_GA_auto( ...
    STAs, mapFile, materialName, paramsGA, txArraySize, K)

% Fully automatic multi-objective AP planning using gamultiobj.
% Returns:
%   APsSet   : cell array of AP layouts (txsite arrays)
%   paretoObj: objectives for the returned solutions [ -cov, apCount, gdop, rssVar ]
%   meta     : struct with extra info (chosen indices, bounds, full pareto size)
meta = struct();
if nargin < 6 || isempty(K)
    K = 4;
end

if isstring(materialName), materialName = char(materialName); end
if iscell(materialName),   materialName = materialName{1}; end

Ns = numel(STAs);
% ---- SPEED: use a subset of STAs for planning only ----
maxPlanSTAs = 400;  % 200–500 recommended
if Ns > maxPlanSTAs
    idxPlan  = randperm(Ns, maxPlanSTAs);
    STAsPlan = STAs(idxPlan);
else
    STAsPlan = STAs;
end
NsPlan = numel(STAsPlan);


% ---- Extract STA XY from planning STAs ----
staXY = zeros(NsPlan,2);
for s = 1:NsPlan
    p = STAsPlan(s).AntennaPosition;
    staXY(s,:) = double(p(1:2)).';
end

% ---- Candidate AP grid derived from STA bounding box (AUTOMATIC) ----
margin   = paramsGA.margin;
gridStep = paramsGA.gridStep;

area = [min(staXY(:,1))-margin, max(staXY(:,1))+margin, ...
        min(staXY(:,2))-margin, max(staXY(:,2))+margin];

xs = area(1):gridStep:area(2);
ys = area(3):gridStep:area(4);
[XX,YY] = meshgrid(xs,ys);
candXY = [XX(:), YY(:)];
Nc = size(candXY,1);

candPos = [candXY, paramsGA.APheight*ones(Nc,1)];

% ---- Build candidate AP objects (all at once) ----
candAP = txsite("cartesian", ...
    "AntennaPosition", candPos.', ...
    "TransmitterFrequency", paramsGA.fc, ...
    "TransmitterPower", paramsGA.TxPower_dBm);

% ---- Raytrace from all candidate APs to all STAs (expensive but needed) ----
pmPlan = propagationModel("raytracing", ...
    "CoordinateSystem","cartesian", ...
    "Method","sbr", ...
    "SurfaceMaterial", materialName, ...
    "MaxNumReflections", paramsGA.maxReflections);

fprintf("MO-GA planning: Candidates=%d | STAsPlan=%d/%d | gridStep=%.2f\n", ...
    Nc, NsPlan, numel(STAs), gridStep);

rays = raytrace(candAP, STAsPlan, pmPlan, "Map", mapFile);
assert(size(rays,2) == NsPlan, "Mismatch: rays computed with STAsPlan, but NsPlan inconsistent.");

% ---- Precompute cover/angles/rssi matrices ----
cover  = false(Nc,NsPlan);
angles = cell(Nc,NsPlan);
rssi   = nan(Nc,NsPlan);

for a = 1:Nc
    for s = 1:NsPlan
        rr = rays{a,s};
        if isempty(rr), continue; end

       [plMin,k] = min([rr.PathLoss]);

        % --- EIRP-limited RSSI model (recommended) ---
        eirpLimit_dBm = paramsGA.TxPower_dBm;
        rssi(a,s) = eirpLimit_dBm - plMin;
        
        if a == 1 && s == 1
            fprintf("EIRP model active | txArray=%dx%d | EIRP=%.1f dBm\n", ...
                txArraySize(1), txArraySize(2), eirpLimit_dBm);
        end
        
        cover(a,s) = (rssi(a,s) >= paramsGA.RxSensitivity);

        aoa = rr(k).AngleOfArrival;
        angles{a,s} = aoa(1);                           % azimuth only (simple geometry proxy)
    end
end

% ---- Automatic bounds for number of APs (no manual AP count) ----
% Use STA coverage radius derived from sensitivity statistics? Keep it implicit via cover matrix.
% We bound AP count so GA doesn't return degenerate 1-AP solutions.

area_m2 = max(1e-6, (area(2)-area(1))*(area(4)-area(3)));

% crude heuristic: each AP “covers” roughly pi*(R^2). We estimate R from STA spread:
Rheur = 0.4 * sqrt(area_m2/pi);                   % heuristic scale
nCoverPerAP = pi*(Rheur^2);
roughMinAP = ceil(paramsGA.minCoverage * area_m2 / max(1e-6,nCoverPerAP));

% --- Heuristic: larger array gain -> allow fewer APs (speed only) ---
gainNow = 10*log10(prod(txArraySize));          % 0 / 3 / 6 dB
minAP_bound = round(roughMinAP - gainNow/3);    % ~3 dB -> 1 AP fewer
minAP_bound = max(3, min(minAP_bound, Nc));     % clamp

maxAP_bound = min(Nc, max(minAP_bound+1, ceil(1.5*minAP_bound)));

paramsGA.minAP_bound = minAP_bound;
paramsGA.maxAP_bound = maxAP_bound;


% ---- Multi-objective fitness with penalties (coverage + spacing) ----
fitness = @(x) apFitnessMO_penalized(x, cover, angles, rssi, candXY, paramsGA);

opts = optimoptions("gamultiobj", ...
    "PopulationType", "bitstring", ...
    "PopulationSize", 120, ...
    "MaxGenerations", 60, ...
    "FunctionTolerance", 1e-6, ...
    "Display","iter");

[XPareto, FPareto] = gamultiobj(fitness, Nc, [], [], [], [], zeros(1,Nc), ones(1,Nc), opts);


fprintf("\n--- Pareto front summary (txArray=%dx%d) ---\n", txArraySize(1), txArraySize(2));
fprintf("Pareto points: %d\n", size(FPareto,1));

% Print first 10 pareto points (or fewer)
M = min(10, size(FPareto,1));
for ii = 1:M
    apCount = sum(XPareto(ii,:) > 0.5);
    cov     = -FPareto(ii,1);      % because obj1 = -coverage
    cost    =  FPareto(ii,2);      % if your obj2 is apCount then this equals apCount
    gdop    =  FPareto(ii,3);
    rssVar  =  FPareto(ii,4);

    fprintf("Pareto #%2d | APs=%2d | cov=%.3f | cost=%.3f | gdop=%.3f | rssVar=%.3f\n", ...
        ii, apCount, cov, cost, gdop, rssVar);
end
fprintf("--- end Pareto summary ---\n\n");


% ---- Decision making (AUTOMATIC representative Pareto points) ----
Fn = (FPareto - min(FPareto,[],1)) ./ (max(FPareto,[],1)-min(FPareto,[],1) + 1e-12);
dIdeal = vecnorm(Fn,2,2);   % knee proxy

labels = ["BestCoverage","BestCost","BestGeometry","KneeCompromise"];

idxFinal = zeros(1,4);
idxUsed  = [];

pickDistinct = @(orderList) orderList(find(~ismember(orderList, idxUsed), 1, 'first'));

% ---- BestCoverage (min obj1) ----
[~, orderCov] = sort(FPareto(:,1), 'ascend');
idxFinal(1) = pickDistinct(orderCov);
idxUsed(end+1) = idxFinal(1);

% ---- BestCost (min obj2) ----
[~, orderCost] = sort(FPareto(:,2), 'ascend');
idxFinal(2) = pickDistinct(orderCost);
idxUsed(end+1) = idxFinal(2);

% ---- BestGeometry (min obj3) ----
[~, orderGeom] = sort(FPareto(:,3), 'ascend');
idxFinal(3) = pickDistinct(orderGeom);
idxUsed(end+1) = idxFinal(3);

% ---- KneeCompromise (min dIdeal) ----
if K>= 4
    [~, orderKnee] = sort(dIdeal, 'ascend');
    idxFinal(4) = pickDistinct(orderKnee);
    %idxUsed(end+1) = idxFinal(4);
end

% Limit by K (K=4 gives all)
idx = idxFinal(1:min(K,4));
labelsUnique = labels(1:numel(idx));

fprintf("\n--- Chosen solutions (txArray=%dx%d) ---\n", txArraySize(1), txArraySize(2));
for k = 1:numel(idx)
    ii = idx(k);
    apCount = sum(XPareto(ii,:) > 0.5);
    cov     = -FPareto(ii,1);
    cost    =  FPareto(ii,2);
    gdop    =  FPareto(ii,3);
    rssVar  =  FPareto(ii,4);

    fprintf("Chosen #%d %-15s | ParetoIdx=%d | APs=%d | cov=%.3f | cost=%.3f | gdop=%.3f | rssVar=%.3f\n", ...
        k, labelsUnique(k), ii, apCount, cov, cost, gdop, rssVar);
end
fprintf("--- end Chosen ---\n\n");


meta.solutionLabels = labelsUnique;
meta.solutionIdx    = idx;
meta.paretoSize     = size(FPareto,1);


% ---- Build AP layouts for the chosen Pareto points ----
APsSet = cell(numel(idx),1);
for k = 1:numel(idx)
    mask = XPareto(idx(k),:) > 0.5;
    APsXY = candXY(mask,:);
    APsSet{k} = buildAPSitesFromXY(APsXY, paramsGA);

end

paretoObj = FPareto(idx,:);


meta.idxChosen   = idx;
meta.minAP_bound = minAP_bound;
meta.maxAP_bound = maxAP_bound;
meta.paretoSize  = size(FPareto,1);
meta.txArraySize   = txArraySize;
meta.candXY        = candXY;          % optional
meta.XPareto       = XPareto;         % for later inspection
meta.FPareto       = FPareto;         % for later inspection
meta.minAP_bound   = minAP_bound;
meta.maxAP_bound   = maxAP_bound;


fprintf("MO-GA Pareto=%d | Chosen=%d | bounds=[%d..%d]\n", meta.paretoSize, numel(idx), minAP_bound, maxAP_bound);
end
