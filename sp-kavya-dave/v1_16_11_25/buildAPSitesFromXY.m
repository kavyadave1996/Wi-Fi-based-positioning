function APs = buildAPSitesFromXY(APsXY, apHeight)
    nAP = size(APsXY, 1);
    APs = txsite.empty;
    for i = 1:nAP
        APs(end+1) = txsite("cartesian", ...
            "AntennaPosition", [APsXY(i,1); APsXY(i,2); apHeight], ...
            "TransmitterFrequency", 5.18e9);
    end
end
