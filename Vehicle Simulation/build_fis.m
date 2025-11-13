%% build_final_drowsiness_fis.m
% Builds a Mamdani FIS where output = max(input MF indices)
fis = mamfis('Name','FinalDrowsinessRisk');

% Input1 VisualFatigue (0..1)
fis = addInput(fis,[0 1],'Name','VisualFatigue');
fis = addMF(fis,'VisualFatigue','trapmf',[0 0 0.25 0.4],'Name','Alert');
fis = addMF(fis,'VisualFatigue','trimf',[0.3 0.5 0.7],'Name','Low');
fis = addMF(fis,'VisualFatigue','trapmf',[0.6 0.8 1 1],'Name','High');

% Input2 SteeringVariance (0..0.5)
fis = addInput(fis,[0 0.5],'Name','SteeringVariance');
fis = addMF(fis,'SteeringVariance','trapmf',[0 0 0.05 0.15],'Name','Stable');
fis = addMF(fis,'SteeringVariance','trimf',[0.1 0.25 0.4],'Name','Erratic');
fis = addMF(fis,'SteeringVariance','trapmf',[0.35 0.45 0.5 0.5],'Name','Dangerous');

% Input3 SpeedStability (0..10)
fis = addInput(fis,[0 10],'Name','SpeedStability');
fis = addMF(fis,'SpeedStability','trapmf',[0 0 1 3],'Name','Stable');
fis = addMF(fis,'SpeedStability','trimf',[2 4 7],'Name','Drifting');
fis = addMF(fis,'SpeedStability','trapmf',[6 9 10 10],'Name','Erratic');

% Input4 LongAccelErratic (0..1)
fis = addInput(fis,[0 1],'Name','LongAccelErratic');
fis = addMF(fis,'LongAccelErratic','trapmf',[0 0 0.15 0.35],'Name','Low');
fis = addMF(fis,'LongAccelErratic','trimf',[0.2 0.45 0.7],'Name','Medium');
fis = addMF(fis,'LongAccelErratic','trapmf',[0.6 0.85 1 1],'Name','High');

% Output FinalDrowsinessRisk (0..1) with 3 MFs: Low(1), Medium(2), High(3)
fis = addOutput(fis,[0 1],'Name','FinalDrowsinessRisk');
fis = addMF(fis,'FinalDrowsinessRisk','trapmf',[0 0 0.15 0.3],'Name','Low');
fis = addMF(fis,'FinalDrowsinessRisk','trimf',[0.2 0.5 0.8],'Name','Medium');
fis = addMF(fis,'FinalDrowsinessRisk','trapmf',[0.7 0.9 1 1],'Name','High');

% Set methods to match your .fis header
fis.AndMethod = 'min';
fis.OrMethod = 'max';
fis.ImpMethod = 'min';
fis.AggregationMethod = 'max';
fis.DefuzzificationMethod = 'centroid';

% Generate all 81 rules where Output = max(input MF indices)
rules = zeros(81,7); % [in1 in2 in3 in4 out weight op]
idx = 1;
for a = 1:3
    for b = 1:3
        for c = 1:3
            for d = 1:3
                out = max([a b c d]); % output MF index
                rules(idx,:) = [a b c d out 1 1]; % weight=1, AND operator
                idx = idx + 1;
            end
        end
    end
end

fis = addRule(fis,rules);

% Save the FIS to file
writeFIS(fis,'FinalDrowsinessRisk.fis');

% Optional: test a few vectors
disp('Example evals:');
fprintf('All 1s -> risk: %.3f\n', evalfis([0.1 0.05 1 0.1], fis)); % low expected
fprintf('One high -> risk: %.3f\n', evalfis([0.7 0.05 1 0.1], fis)); % high expected
fprintf('Medium steering & medium accel -> risk: %.3f\n', evalfis([0.2 0.25 1 0.4], fis)); % medium expected
