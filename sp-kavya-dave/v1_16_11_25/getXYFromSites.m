function xy = getXYFromSites(sites)
% Return [x y] (meters) for txsite/rxsite in cartesian coords
    N = numel(sites);
    xy = zeros(N,2);
    for i = 1:N
        if isprop(sites,'AntennaPosition')
            p = sites(i).AntennaPosition;   % [x;y;z]
        elseif isprop(sites,'Position')
            p = sites(i).Position;          % [x;y;z] alternative
        else
            error('Sites lack AntennaPosition/Position properties.');
        end
        if isrow(p), p = p.'; end
        xy(i,:) = double(p(1:2)).';
    end
end
