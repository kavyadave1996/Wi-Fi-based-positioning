function APs = placeAPsGrid(numAPs, areaSize)
% Simple near-uniform grid placement in [0,areaSize]x[0,areaSize]
    kx = ceil(sqrt(numAPs));
    ky = ceil(numAPs / kx);
    xs = linspace(areaSize*0.1, areaSize*0.9, kx);
    ys = linspace(areaSize*0.1, areaSize*0.9, ky);
    [XX,YY] = meshgrid(xs,ys);
    pts = [XX(:) YY(:)];
    pts = pts(1:numAPs, :);

    APs = repmat(txsite, 1, numAPs);
    for i = 1:numAPs
        APs(i) = txsite( ...
            "Name", sprintf("AP%d", i), ...
            "Position", [pts(i,1) pts(i,2) 1.5], ...
            "AntennaHeight", 1.5, ...
            "TransmitterFrequency", 5.18e9);
    end
end