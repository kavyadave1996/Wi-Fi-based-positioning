function F = apFitnessBoundedGDOP(x, cover, candXY, staXY, minAP_bound, maxAP_bound)

    % IMPORTANT: force column vector so it matches cover(:,s)
    sel = (x(:) > 0.5);              % Nc×1
    apCount = sum(sel);

    % ---- Objective 1: coverage shortfall ----
    Kmin = 3;
    nSeen = sum(cover(sel,:), 1);    % 1×Ns
    coverageRatio = mean(nSeen >= Kmin);
    covShort = 1 - coverageRatio;

    % ---- Objective 2: cost ----
    cost = apCount;

    % ---- Objective 3: GDOP-like geometry ----
    Ns = size(cover,2);
    gdopSum = 0;

    for s = 1:Ns
        % selected APs that also cover this STA
        idx = find(sel & cover(:,s));     % <= Nc always (NOW FIXED)

        if numel(idx) < 3
            gdopSum = gdopSum + 1e3;
            continue;
        end

        p = staXY(s,:);        % 1×2
        A = candXY(idx,:);     % M×2

        d = sqrt(sum((A - p).^2, 2));     % M×1
        u = (A - p) ./ (d + 1e-9);        % M×2

        H = [u, ones(size(u,1),1)];       % M×3  (ux uy 1)

        G = H.' * H;                      % 3×3
        if rcond(G) < 1e-12
            gdopSum = gdopSum + 1e3;
            continue;
        end

        Q = inv(G);
        gdop2D = sqrt(trace(Q));          % lower is better
        gdopSum = gdopSum + min(gdop2D, 1e3);
    end

    gdopObj = gdopSum / Ns;

    % ---- Penalty for AP bounds ----
    pen = 0;
    if apCount < minAP_bound
        pen = pen + 1e4 * (minAP_bound - apCount)^2;
    elseif apCount > maxAP_bound
        pen = pen + 1e4 * (apCount - maxAP_bound)^2;
    end

    % Apply penalty to all objectives
    F = [covShort + pen, cost + pen, gdopObj + pen];
end
