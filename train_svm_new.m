% Title: SVM Model Retraining using fitcsvm (For Drowsiness Detection)
clc;
clear all;
close all;

%% 1. DEFINE TRAINING DATA (REPLACE WITH YOUR REAL DATA)
% X = [LC/TF, RC/TF, MC/TF, TC]
% Each row is a training sample (an 8-second epoch of driver behavior).
% We are adding more samples to create a robust 'Non-Fatigue' boundary.
Feature = [
    % --- Non-Fatigue Samples (10 samples) ---
    0.02, 0.03, 0.00, 12;   % Normal driving, good blinking
    0.04, 0.05, 0.01, 15;   % Active blinking
    0.01, 0.02, 0.00, 10;   % Calm, steady focus
    0.05, 0.06, 0.00, 18;   % High end of normal blinking
    0.03, 0.03, 0.00, 14;
    0.02, 0.03, 0.00, 11;
    0.01, 0.01, 0.00, 9;    % Relaxed but alert
    0.06, 0.07, 0.01, 20;   % Slightly more blinking
    0.04, 0.04, 0.00, 13;
    0.00, 0.00, 0.00, 15;


    % --- Fatigue Samples (6 samples) ---
    0.35, 0.38, 0.20, 8;    % Long closures, yawning, low blink count
    0.20, 0.22, 0.08, 25;   % High closure, slightly higher blink (early fatigue)
    0.10, 0.11, 0.05, 3;    % Very low blink rate (zoning out/micro-sleep risk)
    0.40, 0.45, 0.15, 5;    % Severe closure, heavy fatigue
    0.25, 0.25, 0.00, 2;    % Extremely low blink count
    0.15, 0.16, 0.10, 10;   % Closure + yawn risk
];

% Y = Labels (must be a cell array of strings or categorical)
Y = {
    'Non-Fatigue'; 'Non-Fatigue'; 'Non-Fatigue'; 'Non-Fatigue'; 'Non-Fatigue';
    'Non-Fatigue'; 'Non-Fatigue'; 'Non-Fatigue'; 'Non-Fatigue'; 'Non-Fatigue';
    'Fatigue'; 'Fatigue'; 'Fatigue'; 'Fatigue'; 'Fatigue'; 'Fatigue';
};


%% 2. TRAIN THE CLASSIFICATION SVM MODEL
% We use fitcsvm with a linear kernel, which is fast and effective for this type of data.
svmStruct = fitcsvm(Feature, Y, ...
                    'KernelFunction', 'linear', ...
                    'Standardize', true);

% Optional: Check cross-validation loss (a measure of model accuracy)
CVMdl = crossval(svmStruct);
loss = kfoldLoss(CVMdl);

disp(['SVM Model Training Complete.']);
disp(['Estimated Cross-Validation Loss: ', num2str(loss)]);

%% 3. SAVE THE NEW MODEL OBJECT
% The main detection script loads 'svm.mat' and expects the variable 'svmStruct'.
save('svm.mat', 'svmStruct');

disp('----------------------------------------------------');
disp('New "svm.mat" file has been successfully created/updated.');
disp('IMPORTANT: Ensure your main drowsiness script uses the PREDICT function now.');
disp('----------------------------------------------------');