function F = apFitnessMO_penalized(x, cover, angles, rssi, candXY, paramsGA)
% Multi-objective fitness:
%   obj1 = -coverage (maximize coverage)
%   obj2 = apCount   (minimize AP count)
%   obj3 = gdop      (minimize geometry penalty)
%   obj4 = rssVar    (minimize RSSI variance)
% Plus penalties for:
%   - coverage shortfall below minCoverage
%   - AP spacing violations (< dMin)
%   - AP count outside [minAP_bound, maxAP_bound]

sel = find(x > 0.5);
apCount = numel(sel);

% Initialize penalty (ALWAYS used)
pen = 0;

% If empty selection => huge penalty
if apCount == 0
    F = [1, 1e3, 1e3, 1e3] + 1e6;
    return;
end

% ----- Objective 1: Coverage -----
cov = mean(any(cover(sel,:), 1));   % [0..1]
obj1 = -cov;

% ----- Objective 2: AP count -----
obj2 = apCount;

% ----- Objective 3: Geometry proxy (lower is better) -----
Ns = size(cover,2);
gdopSum = 0;

for s = 1:Ns
    ang = [];
    for a = sel(:).'
        if ~isempty(angles{a,s})
            ang(end+1) = angles{a,s}; %#ok<AGROW>
        end
    end

    if numel(ang) >= 2
        gdopSum = gdopSum + 1/(var(ang) + 1e-6);
    else
        gdopSum = gdopSum + 1e2; % no angular diversity => penalty
    end
end

obj3 = gdopSum / Ns;

% ----- Objective 4: RSSI stability (lower variance is better) -----
rssVar = var(rssi(sel,:), 0, 1, "omitnan");  % variance across APs per STA
rssVar(isnan(rssVar)) = 1e2;
obj4 = mean(rssVar);

% ===================== Penalties =====================

% 1) Coverage requirement
if isfield(paramsGA, "minCoverage") && cov < paramsGA.minCoverage
    pen = pen + 1000 * (paramsGA.minCoverage - cov)^2;
end

% 2) AP spacing (avoid clustering)
if isfield(paramsGA, "dMin") && apCount >= 2
    XY = candXY(sel,:);
    D  = pdist(XY);
    viol = max(0, paramsGA.dMin - D);
    pen = pen + 100 * sum(viol.^2);
end

% 3) HARD AP count bounds (robust even if linear constraints are ignored)
if isfield(paramsGA, "minAP_bound") && apCount < paramsGA.minAP_bound
    pen = pen + 1e6 * (paramsGA.minAP_bound - apCount)^2;
end

if isfield(paramsGA, "maxAP_bound") && apCount > paramsGA.maxAP_bound
    pen = pen + 1e6 * (apCount - paramsGA.maxAP_bound)^2;
end

nAP = sum(x > 0.5);

pen = 0;
if nAP < paramsGA.minAP_bound
    pen = pen + 1000 * (paramsGA.minAP_bound - nAP);
end
if nAP > paramsGA.maxAP_bound
    pen = pen + 1000 * (nAP - paramsGA.maxAP_bound);
end

F = [obj1, obj2, obj3, obj4] + pen;


end
