function [APsXY, mask, score] = optimizeAPPlacementWithGA(STAs, area, gridStep, minAPs, maxAPs, alpha, lambda)
% GA selects which candidate grid points become APs (and how many)
    xs = area(1):gridStep:area(2);
    ys = area(3):gridStep:area(4);
    [XX,YY] = meshgrid(xs,ys);
    candXY = [XX(:) YY(:)];
    Nc = size(candXY,1);

    staXY = getXYFromSites(STAs);

    % Linear constraint: minAPs <= sum(bits) <= maxAPs
    A = [ ones(1,Nc); -ones(1,Nc) ];
    b = [ maxAPs;     -minAPs    ];

    fitnessFcn = @(bits) apFitness(bits, candXY, staXY, alpha, lambda);

    opts = optimoptions('ga', ...
        'PopulationType','bitstring', ...
        'PopulationSize', 60, ...
        'MaxGenerations', 40, ...
        'UseVectorized', false, ...
        'Display','iter');

    [bestBits, bestScore] = ga(fitnessFcn, Nc, A, b, [], [], [], [], [], opts);

    mask  = logical(bestBits(:));
    APsXY = candXY(mask,:);
    score = bestScore;
end




