function predictedLabels = scores2label(scores, classes)
% scores2label Converts network softmax scores to class labels
%   scores: N-by-C matrix where each row is a softmax output over C classes
%   classes: array of class names or categorical labels

[~, idx] = max(scores, [], 2);  % Get index of max score per row
predictedLabels = classes(idx); % Assign class based on index
end
