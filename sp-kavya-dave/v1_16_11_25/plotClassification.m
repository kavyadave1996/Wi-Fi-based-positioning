% function accuracy = plotClassification(YTrue, YPred, locs)
% %PLOTCLASSIFICATION Visualize indoor localization results
% %   plotClassification(YTRUE, YPRED, LOCS) produces a 3D scatter plot of
% %   true STA positions, LOCS, on a map. These are colored corresponding
% %   to their predicted class label, (YPRED). The true labels, YTRUE are 
% %   then compared to the predictions and a confusion chart and percent 
% %   accuracy are displayed.
% 
% % Convert class to "one-hot" logical vector
% numClasses = length(unique(YTrue));
% title({'{\bf{CNN Location Prediction}}';'\fontsize{10}True STA positions coloured by Predicted Class'},'FontWeight','Normal');
% 
% % Visualize the class areas
% % Conference Room
% v1= [0 2.75 0.05; 0 0 0.05; 5 0 0.05; 5 2.75 0.05];
% f1 = [1 2 3 4];
% patch('Faces', f1, 'Vertices', v1, 'FaceColor', 'B', 'FaceAlpha', 0.3);
% 
% % Storage
% v2= [0 2.75 0.05; 0 8.0 0.05; 0.5 8 0.05; 0.5 2.75 0.05];
% f2 = [1 2 3 4];
% patch('Faces', f2, 'Vertices', v2, 'FaceColor', 'Y', 'FaceAlpha', 0.3);
% 
% % Desk 1 
% v3= [0.5 6.5 0.05; 0.5 8.0 0.05; 2.5 8 0.05; 2.5 6.5 0.05];
% f3 = [1 2 3 4];
% patch('Faces', f3, 'Vertices', v3, 'FaceColor', 'G', 'FaceAlpha', 0.3);
% 
% % Desk 2
% v4= [2.5 6.5 0.05; 2.5 8.0 0.05; 5 8 0.05; 5 6.5 0.05];
% f4 = [1 2 3 4];
% patch('Faces', f4, 'Vertices', v4, 'FaceColor', 'M', 'FaceAlpha', 0.3);
% 
% % Desk 3
% v5= [3.5 6.5 0.05; 5 6.5 0.05; 5 4.5 0.05; 3.5 4.5 0.05];
% f5 = [1 2 3 4];
% patch('Faces', f5, 'Vertices', v5, 'FaceColor', 'C', 'FaceAlpha', 0.3);
% 
% % Desk 4
% v6= [3.5 4.5 0.05; 5 4.5 0.05; 5 2.75 0.05; 3.5 2.75 0.05];
% f6 = [1 2 3 4];
% patch('Faces', f6, 'Vertices', v6, 'FaceColor', 'R', 'FaceAlpha', 0.3);
% 
% % Office (white) not plotted - remaining space
% locations = sort(categories(YTrue));
% 
% % Visualise the predicted receiver classes
% colors = {'b','g','m', 'c' ,'r','w','y'};
% 
% for p=1:size(YTrue,2)
%     x = colors(strcmp(YPred(p), locations));
%     scatter3(locs(1,p), locs(2,p), locs(3,p), char(x), 'filled');
% end
% 
% % CORRECTED: Create proper legend handles
% % ... Your scatter3 plotting code above ...
% 
% l = gobjects(numClasses,1); % Use gobjects for plot handles
% for q = 1:numClasses
%     l(q) = scatter3(nan, nan, nan, 100, char(colors(q)), "filled", 'MarkerEdgeColor', 'k');
% end
% 
% % Ensure locations is a cell array of strings
% if iscategorical(locations)
%     locations = cellstr(locations);
% elseif isstring(locations)
%     locations = cellstr(locations);
% end
% 
% % DEBUG
% disp('Legend handles:'); disp(l);
% disp('Legend labels:'); disp(locations);
% disp(['# Handles: ' num2str(length(l)) ', # Labels: ' num2str(length(locations))]);
% 
% % Remove empty handles (should not be needed, but safe)
% valid = isgraphics(l, 'scatter');
% l = l(valid);
% locations = locations(valid);
% 
% % Now create the legend
% lgd = legend(l, locations, 'Location', 'bestoutside');
% lgd.Title.String = "Predicted Class";
% 
% 
% % Plot the confusion chart and Accuracy
% figure
% cm = confusionchart(cellstr(YTrue),cellstr(YPred));
% accuracy = sum(diag(cm.NormalizedValues))/sum(cm.NormalizedValues(:))*100;
% cm.title(['Accuracy: ',num2str(accuracy),'%']);
% end
function accuracy = plotClassification(YTrue, YPred, locs)
% Robust indoor localization visualization:
% - Keeps your room patches
% - Works for any number of classes (dynamic colormap)
% - Aligns categories so comparisons are valid
% - Returns overall accuracy (%)

% ---------- Normalize inputs ----------
YTrue = categorical(YTrue);
YPred = categorical(YPred, categories(YTrue));  % align to same category set

if size(locs,1) ~= 3 && size(locs,2) == 3
    locs = locs.';  % ensure 3 x N
end
N = numel(YTrue);
cats = categories(YTrue);
K    = numel(cats);

% ---------- Title ----------
title({'{\bf CNN Location Prediction}', ...
       '\fontsize{10}True STA positions coloured by Predicted Class'}, ...
       'FontWeight','Normal');

% ---------- Room patches (your shapes/colors kept) ----------
hold on;
v1= [0 2.75 0.05; 0 0 0.05; 5 0 0.05; 5 2.75 0.05];     patch('Faces',[1 2 3 4],'Vertices',v1,'FaceColor','b','FaceAlpha',0.3);
v2= [0 2.75 0.05; 0 8.0 0.05; 0.5 8 0.05; 0.5 2.75 0.05]; patch('Faces',[1 2 3 4],'Vertices',v2,'FaceColor','y','FaceAlpha',0.3);
v3= [0.5 6.5 0.05; 0.5 8.0 0.05; 2.5 8 0.05; 2.5 6.5 0.05]; patch('Faces',[1 2 3 4],'Vertices',v3,'FaceColor','g','FaceAlpha',0.3);
v4= [2.5 6.5 0.05; 2.5 8.0 0.05; 5 8 0.05; 5 6.5 0.05];     patch('Faces',[1 2 3 4],'Vertices',v4,'FaceColor','m','FaceAlpha',0.3);
v5= [3.5 6.5 0.05; 5 6.5 0.05; 5 4.5 0.05; 3.5 4.5 0.05];   patch('Faces',[1 2 3 4],'Vertices',v5,'FaceColor','c','FaceAlpha',0.3);
v6= [3.5 4.5 0.05; 5 4.5 0.05; 5 2.75 0.05; 3.5 2.75 0.05]; patch('Faces',[1 2 3 4],'Vertices',v6,'FaceColor','r','FaceAlpha',0.3);

% ---------- Dynamic colormap for any K ----------
if K <= 64
    cmap = lines(K);
else
    cmap = hsv(K);
end

% ---------- Scatter points coloured by PREDICTED class ----------
for q = 1:K
    idx = (YPred == cats{q});
    if any(idx)
        scatter3(locs(1,idx), locs(2,idx), locs(3,idx), ...
                 16, cmap(q,:), 'filled', 'MarkerEdgeColor','none');
    end
end
grid on; axis equal;
xlabel('X [m]'); ylabel('Y [m]'); zlabel('Z [m]');
title(sprintf('Classification map (%d classes)', K));

% ---------- Legend (sampled if too many) ----------
maxLegend = 15;
if K <= maxLegend
    legIdx = 1:K;
else
    legIdx = round(linspace(1, K, maxLegend));
end
% Create dummy handles for legend
L = gobjects(numel(legIdx),1);
for i = 1:numel(legIdx)
    q = legIdx(i);
    L(i) = scatter3(nan, nan, nan, 100, cmap(q,:), 'filled', 'MarkerEdgeColor','k');
end
% Create legend and then set the Title string (compatible)
lg = legend(L, cats(legIdx), 'Location', 'eastoutside');

% Set legend title if possible (newer MATLAB exposes Title.String)
if isprop(lg, 'Title') && isprop(lg.Title, 'String')
    lg.Title.String = 'Predicted Class';
end

% ---------- Accuracy + Confusion chart ----------
accuracy = 100 * mean(YPred(:) == YTrue(:));

figure('Name','Confusion');
cm = confusionchart(YTrue, YPred, 'Normalization','row-normalized');
cm.Title = sprintf('Accuracy: %.2f%%', accuracy);
cm.RowSummary = 'row-normalized'; cm.ColumnSummary = 'off';
end
