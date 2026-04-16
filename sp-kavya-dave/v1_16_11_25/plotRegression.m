function meanErr = plotRegression(YTrue, YPred)
%PLOTREGRESSION Visualize indoor localization results
%   plotRegression(YTRUE, YPRED) produces a 3D scatter plot of
%   true STA positions, YTRUE, on a map. These are colored corresponding
%   to magnitude of distance error of predicted positions, (YPRED). The
%   calculated error is used to produce a CDF plot.

    YTrue = YTrue';
    mErr = zeros([1 size(YTrue, 1)]);
    
    % Compute the distance error
    for i=1:size(YTrue,1)
        mErr(i) = double(norm(YTrue(i,:) - YPred(i,:)));
    end

    % Set the color bar properties
    minErr = floor(min(mErr))*10;
    maxErr = ceil(max(mErr))*10;
    numColors =  (maxErr - minErr)/5;
    cm = colormap(jet(numColors));

    % Plot the true receiver locations - coloured by magnitude of error
    for i = 1:size(YTrue,1)
        cmIdx = find((mErr(i)*10 - (minErr:5:maxErr))<0, 1) - 1;
        if cmIdx >numColors
            cmIdx = numColors;
        end
        scatter3(YTrue(i, 1), YTrue(i, 2), YTrue(i, 3), 'MarkerEdgeColor', cm(cmIdx,:), 'MarkerFaceColor', cm(cmIdx,:), 'MarkerFaceAlpha', 1.0);
    end

    % Create colorbar
    cb = colorbar; % ('direction', 'reverse');
    cb.Label.String = 'Distance Error (m)';
    cbLim = cb.Limits;
    cb.Ticks = cbLim(1) + diff(cbLim)/(2*numColors) + ...
        (0:numColors-1)*diff(cbLim)/numColors;
    cb.TickLabels = (minErr/10):.5:(maxErr-5/10);
    title({'{\bf{CNN Position Prediction}}';'\fontsize{10}True STA Positions coloured by Distance Error'},'FontWeight','Normal');
    
    % Plot CDF and display mean distance error
    figure
    stairs(sort(mErr),(1:length(mErr))/length(mErr));
    meanErr = mean(mErr);
    grid on;
    xlabel('Distance error (m)') 
    ylabel('Cumulative Probability') 
    title(['CDF - Positioning Error  ', '(Mean = ',num2str(round(meanErr,2)),'m)']);

end