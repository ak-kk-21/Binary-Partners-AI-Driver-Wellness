% Title: Baseline Data Collection for Non-Fatigue State
clc;
clear all;
close all;

%% Configuration and Setup (Adapted from Drowsiness Detection)
load DB 
cl = {'open','close'}; 
dim = [30 60; 30 60; 40 65];

% Initialize Webcam and Detectors
cam = webcam(1); 
faceDetector = vision.CascadeObjectDetector;   
leftEyeDetector = vision.CascadeObjectDetector('LeftEye'); 
rightEyeDetector = vision.CascadeObjectDetector('RightEye'); 
faceDetectorM = vision.CascadeObjectDetector('Mouth'); 

% --- Feature Accumulators ---
LC = 0;     % Left eye close counter
RC = 0;     % Right eye close counter
MC = 0;     % Mouth open counter
TF = 0;     % Total frame counter
TC = 0;     % Total close transitions (blink rate)
c1p = 1;    % Previous state of the left eye (1=open)

target_duration_sec = 60; % *** RUN FOR 60 SECONDS ***

disp('----------------------------------------------------');
% --- PROMPT FOR USER ID ---
user_id = input('Enter unique user ID (e.g., John_Alert, Jane_Fatigue): ', 's');
disp(['Starting baseline collection for user: ', user_id, ' for ', num2str(target_duration_sec), ' seconds.']);
disp('Please sit alert and blink naturally during this time.');
disp('----------------------------------------------------');

tic % Start the clock

while toc < target_duration_sec
    im = snapshot(cam); 
    
    % Only showing the raw image to minimize processing time during collection
    imshow(im) 
    title(['User: ', user_id, ' | Remaining: ', num2str(round(target_duration_sec - toc)), ' s']);
    drawnow; % Update figure window
    
    bbox = step(faceDetector, im); 
    
    if ~isempty(bbox);
        bbox = bbox(1,:);
        Ic = imcrop(im,bbox);
        
        % --- Dual Eye Detection Logic (Only necessary parts for cropping) ---
        [h, w, ~] = size(Ic);
        left_search_bbox = [1, 1, round(w*0.5), round(h*0.6)];
        Ic_left_search = imcrop(Ic, left_search_bbox);
        right_search_bbox = [round(w*0.5), 1, round(w*0.5), round(h*0.6)];
        Ic_right_search = imcrop(Ic, right_search_bbox);
        
        bboxL = step(leftEyeDetector, Ic_left_search);
        bboxR = step(rightEyeDetector, Ic_right_search);
        
        Leye_raw = []; 
        Reye_raw = []; 
        eyes_detected = false;
        lowest_eye_y = 0;

        if ~isempty(bboxL) && ~isempty(bboxR)
            eyes_detected = true;
            Leye_raw = imcrop(Ic_left_search, bboxL(1,:));
            Reye_raw = imcrop(Ic_right_search, bboxR(1,:));
            
            % Minimal check for mouth blackout calculation (needed for mouth detection later)
            left_eye_pos_in_Ic = [bboxL(1,1) + left_search_bbox(1) - 1, ...
                                  bboxL(1,2) + left_search_bbox(2) - 1, ...
                                  bboxL(1,3), bboxL(1,4)];
            right_eye_pos_in_Ic = [bboxR(1,1) + right_search_bbox(1) - 1, ...
                                   bboxR(1,2) + right_search_bbox(2) - 1, ...
                                   bboxR(1,3), bboxR(1,4)];
            lowest_eye_y = max(left_eye_pos_in_Ic(2) + left_eye_pos_in_Ic(4), ...
                               right_eye_pos_in_Ic(2) + right_eye_pos_in_Ic(4));
        end
        
        if eyes_detected
            
            % Blackout top for mouth detection
            blackout_line = lowest_eye_y + round(h * 0.15); 
            if blackout_line < 1, blackout_line = 1; end
            if blackout_line > h, blackout_line = h; end
            Ic(1:blackout_line,:,:) = 0; 

            % Detect Mouth
            bboxM = step(faceDetectorM, Ic); 
            
            if ~isempty(bboxM);
                [~, idx] = max(bboxM(:, 2)); 
                Emouth_raw = imcrop(Ic,bboxM(idx,:));
            else
                Emouth_raw = []; % Mouth detection failed
            end
            
            % --- Feature Extraction ---
            if ~isempty(Leye_raw) && ~isempty(Reye_raw) && ~isempty(Emouth_raw)
                
                Leye = rgb2gray(imresize(Leye_raw,[dim(1,1) dim(1,2)]));
                Reye = rgb2gray(imresize(Reye_raw,[dim(2,1) dim(2,2)]));
                Emouth = rgb2gray(imresize(Emouth_raw,[dim(3,1) dim(3,2)]));

                % Template Matching (using c1, c2, c3 for open/close state)
                c1 = match_DB(Leye,DBL);
                c2 = match_DB(Reye,DBR);
                c3 = match_DB(Emouth,DBM);
                
                % --- Accumulation Logic ---
                if c1 == 2
                    LC = LC+1;
                    if c1p == 1
                        TC = TC+1;
                    end
                end
                if c2==2
                    RC = RC+1;
                end
                if c3 == 1
                    MC = MC + 1;
                end
                
                TF = TF + 1; % Increment total frames only if features were calculated
                c1p = c1; % Update previous state
            end
        end
    end
end

% --- CLEANUP ---
clear cam; 
close all;

%% Phase 2: Calculate Baseline Features and Save
total_time = toc; % Actual elapsed time

if TF > 0
    % Ratios are calculated over the number of frames processed (TF)
    baseline_LC_Ratio = LC / TF;
    baseline_RC_Ratio = RC / TF;
    baseline_MC_Ratio = MC / TF;
    baseline_TC_Count = TC;
    
    baseline_feature_vector = [baseline_LC_Ratio, baseline_RC_Ratio, baseline_MC_Ratio, baseline_TC_Count];

    % --- DATA STORAGE LOGIC ---
    data_file = 'collected_baselines.mat';
    
    if exist(data_file, 'file') == 2
        % If file exists, load it, append the new data, and save
        load(data_file, 'AllFeatures', 'UserIDs');
        AllFeatures = [AllFeatures; baseline_feature_vector];
        UserIDs = [UserIDs; user_id];
        save(data_file, 'AllFeatures', 'UserIDs');
        disp(['Saved new data point for user ', user_id, ' to ', data_file, '.']);
    else
        % If file does not exist, create it
        AllFeatures = baseline_feature_vector;
        UserIDs = {user_id};
        save(data_file, 'AllFeatures', 'UserIDs');
        disp(['Created new data file: ', data_file, ' and saved first data point.']);
    end
    
    disp('----------------------------------------------------');
    disp('Final Feature Vector:');
    disp(num2str(baseline_feature_vector, '%.4f  '));
    disp('----------------------------------------------------');

else
    disp('Error: No frames were successfully processed. Check camera connection and lighting.');
end