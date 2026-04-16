function zones = makeZonesFromImage(mapFile, imgFile)
% makeZonesFromImage  Draw zone polygons in STL XY coordinates and save them
%
% Usage:
%   makeZonesFromImage("layout.stl","labeled_floor_plan.png")

    % ---- Load STL and normalize units ----
    TR = stlread(mapFile);
    V  = TR.Points;

    stlMin_raw = min(V,[],1);
    stlMax_raw = max(V,[],1);
    span = stlMax_raw - stlMin_raw;

    stlScale = 1;
    if max(span(1:2)) > 1000
        stlScale = 0.001;  % mm → m
    end

    V = V * stlScale;
    stlMin = min(V,[],1);
    stlMax = max(V,[],1);

    % ---- Load labeled image ----
    I = imread(imgFile);

    figure('Color','w');
    imagesc([stlMin(1) stlMax(1)], [stlMin(2) stlMax(2)], flipud(I));
    set(gca,'YDir','normal');
    axis equal tight;
    title('Draw each zone polygon, double-click to finish');
    xlabel('X (STL)'); ylabel('Y (STL)');

    % ---- Zone names (must match training labels) ----
    zoneOrder = ["OpenOffice","FocusArea","Kitchen","Conference", ...
                 "Corridor","PrivateOff","Storage","Reception"];

    zones = struct();

    for k = 1:numel(zoneOrder)
        name = zoneOrder(k);
        disp("Draw zone: " + name);
        h = drawpolygon('LineWidth',2);
        zones.(name) = h.Position;   % Nx2 (STL XY)
    end

    save("zones_STLXY.mat","zones");
    disp("Saved zones to zones_STLXY.mat");
end
