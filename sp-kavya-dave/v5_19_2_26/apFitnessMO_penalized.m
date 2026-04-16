function F = apFitnessMO_penalized(x, cover, angles, rssi, candXY, paramsGA)

    sel = find(x > 0.5);
    apCount = numel(sel);

    % 1) Immediate exit for 0 APs
    if apCount == 0
        F = [1, 1e5, 1e5, 1e5];
        return;
    end

    % 2) Objective 1: Coverage shortfall (Minimize)
    Kmin = 3;
    nSeen = sum(cover(sel,:), 1);        % 1×Ns
    coverageRatio = mean(nSeen >= Kmin); % 0..1  (>=3 APs per STA)
    covObj = 1 - coverageRatio;          % minimize
    cov = coverageRatio;                  % for penalty check

    % 3) Objective 2: Cost (Minimize)
    costObj = apCount;

    % 4) Objective 3: Geometry proxy (Minimize)
    Ns = size(cover,2);
    geomSum = 0;

    for s = 1:Ns
        ang = [];
        for a = sel(:).'
            if ~isempty(angles{a,s})
                ang(end+1) = angles{a,s};
            end
        end

        if numel(ang) >= 2
            v = var(ang);
            geomSum = geomSum + (1 / (v + 1e-3));
        else
            geomSum = geomSum + 100;
        end
    end

    geomRaw = geomSum / Ns;
    gdopObj = min(1, geomRaw / 100);   % normalized

    % 5) Objective 4: RSSI stability (Minimize)
    rV = var(rssi(sel,:), 0, 1, "omitnan");
    rV(isnan(rV)) = 10;
    rssiVarObj = mean(rV);

    % ===================== PENALTIES =====================
    penCoverage = 0;
    penSpacing  = 0;
    penBounds   = 0;

    if isfield(paramsGA, "minCoverage") && cov < paramsGA.minCoverage
        penCoverage = 1e4* (paramsGA.minCoverage - cov)^2;
    end

    if apCount >= 2 && isfield(paramsGA,"dMin") && ~isempty(paramsGA.dMin)
        D = pdist(candXY(sel,:));
        penSpacing = 50 * sum(max(0, paramsGA.dMin - D).^2);
    end

    if isfield(paramsGA,"minAP_bound") && apCount < paramsGA.minAP_bound
        penBounds = 1000 * (paramsGA.minAP_bound - apCount)^2;
    elseif isfield(paramsGA,"maxAP_bound") && apCount > paramsGA.maxAP_bound
        penBounds = 1000 * (apCount - paramsGA.maxAP_bound)^2;
    end

    pen = penCoverage + penSpacing + penBounds;

    % ===================== FINAL OBJECTIVES =====================
    F = [covObj + pen, costObj, gdopObj, rssiVarObj];


end
