function kneeIdx = pickKneePoint(F)
% F: Pareto objective matrix (N x M), all objectives are minimized
% returns index of knee point as minimum distance to utopia in normalized objective space

    Fmin = min(F,[],1);
    Fmax = max(F,[],1);
    denom = (Fmax - Fmin);
    denom(denom == 0) = 1;

    Fn = (F - Fmin) ./ denom;  % normalize to [0,1]
    d = sqrt(sum(Fn.^2, 2));   % distance to utopia [0,0,0,...]
    kneeIdx = find(d == min(d), 1, "first");
end
