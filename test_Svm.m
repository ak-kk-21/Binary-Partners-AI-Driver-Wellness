clc;
clear all;
close all;
%%
load fisheriris
xdata = meas(51:end,3:4);
group = species(51:end);

% --- START CHANGES: Replacing svmtrain with fitcsvm ---

% 1. Train the SVM Model using fitcsvm.
% We use a linear kernel and standardize the data for good practice.
svmModel = fitcsvm(xdata, group, 'KernelFunction', 'linear', 'Standardize', true);

% 2. Manually plot the decision boundary (replaces 'showplot', true).
figure;
h = gscatter(xdata(:,1), xdata(:,2), group, 'rb', 'oo');
hold on;
title('SVM Classification of Iris Data (Versicolor and Virginica)');
xlabel('Petal Length (cm)');
ylabel('Petal Width (cm)');

% Create a fine grid of points to cover the plot area
d = 0.02; 
[x1Grid, x2Grid] = meshgrid(min(xdata(:,1)):d:max(xdata(:,1)), ...
                            min(xdata(:,2)):d:max(xdata(:,2)));
XGrid = [x1Grid(:), x2Grid(:)];

% Predict the classification for every point on the grid
[~, scores] = predict(svmModel, XGrid);

% Plot the classification region boundary (where score is zero)
% We use the score from the second class (Virginica)
contour(x1Grid, x2Grid, reshape(scores(:,2), size(x1Grid)), [0 0], 'k--', 'LineWidth', 2);

% Highlight Support Vectors (key points of the boundary)
sv = svmModel.SupportVectors;
plot(sv(:,1), sv(:,2), 'ko', 'MarkerSize', 8, 'LineWidth', 2);

% --- END CHANGES ---

% 3. Classify the new data point [5 2] using the predict function (replaces svmclassify)
newData = [5 2];
species = predict(svmModel, newData);

% Plot the classified point for visualization
plot(newData(1), newData(2), 'kp', 'MarkerSize', 14, 'LineWidth', 2, 'MarkerFaceColor', 'c');
text(newData(1) + 0.05, newData(2), species{1}, 'Color', 'c', 'FontSize', 12, 'FontWeight', 'bold');

hold off;

disp(['The new data point [5 2] is classified as: ', species{1}])