function out = isLayer(lgraph, layerName)
    names = arrayfun(@(x)x.Name, lgraph.Layers, "UniformOutput", false);
    out = any(strcmp(layerName, names));
end
