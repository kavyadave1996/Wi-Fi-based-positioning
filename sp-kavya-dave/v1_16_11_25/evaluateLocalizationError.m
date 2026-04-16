% --- Helper Functions ---
function locErrorVec = evaluateLocalizationError(rays, APs, STAs)
    % Calculate localization error based on ray tracing data
    locErrorVec = [];  % Initialize an empty vector for localization errors
    N = numel(STAs);  % Number of STAs
    
    % Iterate over each STA and calculate its localization error
    for i = 1:N
        % Get the position of the STA
        truePosition = [STAs(i).AntennaPosition(1), STAs(i).AntennaPosition(2)];
        
        % Simulated position based on ray tracing (you can modify this to match your setup)
        simulatedPosition = calculateSimulatedPosition(rays, APs, STAs, i);  % Placeholder function
        
        % Calculate the error (Euclidean distance between true and simulated positions)
        locErrorVec(i) = norm(truePosition - simulatedPosition);
    end
end

function posErrorVec = evaluatePositioningError(rays, APs, STAs)
    % Calculate positioning error based on ray tracing data
    posErrorVec = [];  % Initialize an empty vector for positioning errors
    N = numel(STAs);  % Number of STAs
    
    % Iterate over each STA and calculate its positioning error
    for i = 1:N
        % Get the true position of the STA
        truePosition = STAs(i).AntennaPosition;
        
        % Simulated position based on ray tracing (you can modify this to match your setup)
        simulatedPosition = calculateSimulatedPosition(rays, APs, STAs, i);  % Placeholder function
        
        % Calculate the distance error (Euclidean distance)
        posErrorVec(i) = norm(truePosition - simulatedPosition);
    end
end

function accuracy = calculateAccuracy(rays, APs, STAs)
    % Calculate the accuracy based on ray tracing and predicted positions
    accuracy = rand();  % Placeholder for accuracy calculation. Replace with your logic
end

function simulatedPosition = calculateSimulatedPosition(rays, APs, STAs, idx)
    % Placeholder function to simulate the position based on ray tracing data
    % You need to modify this based on your setup for calculating the simulated position
    simulatedPosition = [rand(), rand()];  % Replace with the actual logic
end