function [training, validation] = dlPositioningSplitDataSet(features, labels, valFraction)
% Robust stratified split for positioning/localization datasets.
% - features: [Ns x Nfeat x Naps x Ncases]
% - labels.position: [3 x Ncases]
% - labels.class: [1 x Ncases] or categorical vector
% - valFraction: fraction assigned to validation (e.g., 0.2)
%
% Returns:
% training.X, training.Y.classification (categorical col), training.Y.regression (3 x N_train)
% validation.X, validation.Y.classification, validation.Y.regression

if nargin < 3
    valFraction = 0.20;
end

% Basic sanity
Nfeatures = size(features, 4);
if isempty(labels) || ~isfield(labels, 'class') || ~isfield(labels, 'position')
    error('dlPositioningSplitDataSet: labels must contain .class and .position fields');
end

% Normalize label shapes
% Make labels.class a categorical column vector
if ~iscategorical(labels.class)
    labels.class = categorical(labels.class);
else
    % remove unused categories
    labels.class = removecats(labels.class);
end
labels.class = labels.class(:);    % N x 1

% Ensure position has matching samples
if size(labels.position, 2) ~= numel(labels.class)
    error('dlPositioningSplitDataSet: labels.position columns (%d) must match labels.class length (%d).', ...
        size(labels.position,2), numel(labels.class));
end

% Main per-class splitting
classes = categories(labels.class);
nClasses = numel(classes);

train_idx = [];
val_idx = [];

fprintf('dlPositioningSplitDataSet: %d total samples, %d classes, valFraction=%.3f\n', Nfeatures, nClasses, valFraction);

rng('shuffle');  % randomize per call

for ci = 1:nClasses
    thisClass = classes{ci};
    idx = find(labels.class == thisClass);   % indices for this class (column indices)
    n = numel(idx);
    if n == 0
        warning('Class %s has zero samples — skipping.', thisClass);
        continue;
    end

    % shuffle indices for randomness
    idx = idx(randperm(n));

    % Desired number of validation samples for this class (at least 1 if possible)
    n_val = max(1, round(valFraction * n));

    % Ensure at least one training sample if possible
    if n - n_val < 1
        if n == 1
            % Only one sample: duplicate into both train & val (warning about leakage)
            warning('Class %s has only 1 sample. Duplicating that sample into both training and validation (possible leakage).', thisClass);
            val_idx = [val_idx; idx(1)];      % validation gets the single index
            train_idx = [train_idx; idx(1)];  % training also gets the same sample (duplication)
            continue;
        else
            % n>1 but rounding caused n_val to be n -> keep one for train
            n_val = n - 1;
        end
    end

    % If computed n_val is 0 (shouldn't happen due to max(1,...)), set to 1
    n_val = max(1, n_val);

    % assign
    val_idx   = [val_idx;   idx(1:n_val)];
    train_idx = [train_idx; idx(n_val+1:end)];
end

% After loop, ensure we have at least one sample for train and val
if isempty(train_idx)
    error('dlPositioningSplitDataSet: no training samples were produced. Check inputs.');
end
if isempty(val_idx)
    warning('dlPositioningSplitDataSet: no validation samples produced — decreasing valFraction may be required. Proceeding with minimal 1 sample in validation.');
    % move one sample from train to val
    move_idx = train_idx(1);
    val_idx = move_idx;
    train_idx(1) = [];
end

% Shuffle final indices
train_idx = train_idx(randperm(numel(train_idx)));
val_idx   = val_idx(randperm(numel(val_idx)));

% Build outputs
training.X = features(:,:,:,train_idx);
training.Y.classification = categorical(labels.class(train_idx), classes);  % categorical col with same categories
training.Y.regression = labels.position(:, train_idx);

validation.X = features(:,:,:,val_idx);
% Align validation categories with training categories to avoid mismatches later
validation.Y.classification = categorical(labels.class(val_idx), categories(training.Y.classification));
validation.Y.regression = labels.position(:, val_idx);

% Diagnostics printout
fprintf('dlPositioningSplitDataSet: produced %d train samples, %d val samples.\n', size(training.X,4), size(validation.X,4));
% Print class counts (optional, comment out if too verbose)
try
    tcounts = countcats(training.Y.classification);
    vcounts = countcats(validation.Y.classification);
    fprintf('Example: first 8 train-class counts: %s\n', mat2str(tcounts(1:min(8,numel(tcounts)))'));
    fprintf('Example: first 8 val-class counts:   %s\n', mat2str(vcounts(1:min(8,numel(vcounts)))'));
catch
    % ignore if countcats not applicable
end

end
