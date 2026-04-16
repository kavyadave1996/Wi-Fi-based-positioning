function f = apFitness(bits, candXY, staXY, coverageRadius, alpha, lambda, beta, minCoverage, dMin)
    mask = bits(:) > 0.5;
    numAP = sum(mask);
    
    % Softer penalty for <3 APs (was 1e6)
    if numAP < 3
        f = 1e4 + (3 - numAP) * 5e3;  % Still penalized but explorable
        return;
    end
    
    APsXY = candXY(mask, :);
    numSTA = size(staXY, 1);
    K = 3;
    
    % ---- Coverage ----
    D = pdist2(staXY, APsXY);
    coveragePerSTA = sum(D <= coverageRadius, 2);
    coverageFraction = mean(coveragePerSTA >= K);
    
    % ---- Geometry (PDOP) ----
    pdopValues = [];
    idxCovered = find(coveragePerSTA >= K);
    
    for ii = idxCovered.'
        [~, idxK] = sort(D(ii, :));
        idxK = idxK(1:min(K, numAP));  % Handle case where numAP < K
        
        if length(idxK) < K
            continue;  % Skip if not enough APs
        end
        
        rel = APsXY(idxK, :) - staXY(ii, :);
        normRel = vecnorm(rel, 2, 2);
        
        % Skip if any AP is too close (avoid division by zero)
        if any(normRel < 0.1)
            continue;
        end
        
        unit = rel ./ normRel;
        G = unit;
        
        % More robust condition number check
        if rcond(G' * G) > 1e-10
            pdopVal = sqrt(trace(inv(G' * G)));
            pdopValues(end+1, 1) = min(pdopVal, 50);  % Cap extreme values
        end
    end
    
    if isempty(pdopValues)
        medianPDOP = 30;  % Softer penalty (was 100)
    else
        medianPDOP = median(pdopValues);
    end
    
    % ---- Spacing penalty (SOFTENED) ----
    if numAP > 1
        DD = squareform(pdist(APsXY));
        minPair = min(DD(DD > 0));
        
        % Smooth penalty instead of hard threshold
        if minPair < dMin
            sepPenalty = (dMin - minPair) / dMin;  % Normalized 0-1
        else
            sepPenalty = 0;
        end
    else
        sepPenalty = 0.5;  % Mild penalty for single AP
    end
    
    % ---- Coverage penalty (SMOOTH) ----
    coverageDeficit = max(0, minCoverage - coverageFraction);
    
    % Smooth sigmoid penalty instead of linear
    coveragePenalty = coverageDeficit / (coverageDeficit + 0.1);  % Bounded 0-1
    
    % ---- Final fitness (BALANCED WEIGHTS) ----
    f = beta * medianPDOP ...              % Geometry quality
        + alpha * coveragePenalty ...      % Coverage requirement
        + lambda * numAP ...               % AP cost
        + 10 * sepPenalty;                 % Spacing (reduced from 1e3)
    
    % Add small noise to break ties and encourage exploration
    f = f + 0.01 * rand();
end