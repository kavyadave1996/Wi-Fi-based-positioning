function STAs = createSTAsCartesian(numSTAs, areaSize, distName)
% Make rxsite STAs in cartesian coords within [0, areaSize]^2 (z = 1.5 m)
    switch string(distName)
        case "uniform"
            % grid with small jitter
            k = ceil(sqrt(numSTAs));
            xs = linspace(areaSize*0.1, areaSize*0.9, k);
            ys = linspace(areaSize*0.1, areaSize*0.9, k);
            [XX,YY] = meshgrid(xs,ys);
            pts = [XX(:) YY(:)];
            if size(pts,1) > numSTAs, pts = pts(1:numSTAs,:); end
            jitter = 0.05*areaSize*(rand(size(pts))-0.5);
            pts = pts + jitter;
        otherwise % "random"
            pts = rand(numSTAs,2) * areaSize;
    end

    STAs = repmat(rxsite, 1, size(pts,1));
    for i = 1:size(pts,1)
        STAs(i) = rxsite( ...
            "Name", sprintf("STA%d", i), ...
            "CoordinateSystem","cartesian", ...
            "AntennaPosition", [pts(i,1); pts(i,2); 1.5]); % 3x1 column
    end
end
