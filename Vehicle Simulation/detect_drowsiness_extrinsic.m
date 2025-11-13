function [FatigueStatus, FeatureOut] = detect_drowsiness_extrinsic(ImageIn)
% DETECT_DROWSINESS_EXTRINSIC: Core function for drowsiness detection.
% This function is called extrinsically by Simulink, allowing it to use
% advanced MATLAB toolboxes and access persistent complex objects.
% -------------------------------------------------------------------------
% 1. PERSISTENT STATE AND INITIALIZATION
% -------------------------------------------------------------------------
persistent faceDetector leftEyeDetector rightEyeDetector faceDetectorM;
persistent svmStruct DBL DBR DBM dim; % Loaded Data Structures
persistent LC RC MC TF TC c1p frame_counter; % Accumulators
persistent last_species; % Holds the last determined status
% Define classification epoch parameters
CLASSIFICATION_EPOCH_FRAMES = 80;
DEFAULT_STATUS = 'Non-Fatigue';
if isempty(faceDetector)
    % Initialize Detectors (can be persistent)
    faceDetector = vision.CascadeObjectDetector;
    leftEyeDetector = vision.CascadeObjectDetector('LeftEye');
    rightEyeDetector = vision.CascadeObjectDetector('RightEye');
    faceDetectorM = vision.CascadeObjectDetector('Mouth');
    
    % Load Data DIRECTLY from base workspace (evalin is necessary here)
    try
        svmStruct = evalin('base', 'svmStruct');
        DBL = evalin('base', 'DBL');
        DBR = evalin('base', 'DBR');
        DBM = evalin('base', 'DBM');
        dim = evalin('base', 'dim');
    catch ME
        % Handle case where data is not loaded (should not happen in Simulink run)
        error('Extrinsic:DataLoadError', ...
              'Failed to load data (svmStruct, DBL, etc.). Ensure all data is loaded in the base workspace.');
    end
    
    LC = 0; RC = 0; MC = 0; TF = 0; TC = 0; c1p = 1;
    frame_counter = 0;
    last_species = DEFAULT_STATUS;
end
% --- Reset/Initialize outputs for this step ---
species = last_species;
FeatureOut = zeros(1, 4);
% -------------------------------------------------------------------------
% 2. MAIN DETECTION LOGIC (Processing one frame)
% -------------------------------------------------------------------------
im = ImageIn;
frame_counter = frame_counter + 1;
% Detect faces
bbox = step(faceDetector, im); 
if ~isempty(bbox)
    bbox = bbox(1,:);
    Ic = imcrop(im, bbox);
    [h, w, ~] = size(Ic);
    
    % --- Dual Eye Detection Logic (Robustness) ---
    left_search_bbox = [1, 1, round(w*0.5), round(h*0.6)];
    Ic_left_search = imcrop(Ic, left_search_bbox);
    right_search_bbox = [round(w*0.5), 1, round(w*0.5), round(h*0.6)];
    Ic_right_search = imcrop(Ic, right_search_bbox);
    
    bboxL = step(leftEyeDetector, Ic_left_search);
    bboxR = step(rightEyeDetector, Ic_right_search);
    
    eyes_detected = false;
    
    if ~isempty(bboxL) && ~isempty(bboxR)
        eyes_detected = true;
        bboxL = bboxL(1,:);
        bboxR = bboxR(1,:);
        
        Leye_raw = imcrop(Ic_left_search, bboxL);
        Reye_raw = imcrop(Ic_right_search, bboxR);
        
        % Calculate blackout line for mouth detection (simplified)
        left_eye_pos_in_Ic = [bboxL(1) + left_search_bbox(1) - 1, bboxL(2) + left_search_bbox(2) - 1, bboxL(3), bboxL(4)];
        lowest_eye_y = left_eye_pos_in_Ic(2) + left_search_bbox(2) - 1 + left_eye_pos_in_Ic(4); 
    end
    
    if eyes_detected
        % Blackout the top of the face 
        blackout_line = lowest_eye_y + round(h * 0.15); 
        if blackout_line < 1, blackout_line = 1; end
        if blackout_line > h, blackout_line = h; end
        Ic(1:blackout_line,:,:) = 0; 
        
        % Detect Mouth
        bboxM = step(faceDetectorM, Ic); 
        Emouth_raw = [];
        
        if ~isempty(bboxM);
            [~, idx] = max(bboxM(:, 2)); 
            Emouth_raw =  imcrop(Ic,bboxM(idx,:));
        end
        
        % --- Feature Extraction and Accumulation ---
        
        Leye = rgb2gray(imresize(Leye_raw,[dim(1,1) dim(1,2)]));
        Reye = rgb2gray(imresize(Reye_raw,[dim(2,1) dim(2,2)]));
        
        % Template Matching
        c1 = match_DB(Leye,DBL);
        c2 = match_DB(Reye,DBR);
        
        if ~isempty(Emouth_raw)
            Emouth = rgb2gray(imresize(Emouth_raw,[dim(3,1) dim(3,2)]));
            c3 = match_DB(Emouth,DBM);
        else
            c3 = 2; % Assume Neutral/Closed Mouth
        end
        
        % Accumulation Logic
        if c1 == 2, LC = LC+1; end
        if c1 == 2 && c1p == 1, TC = TC+1; end
        if c2==2, RC = RC+1; end
        if c3 == 1, MC = MC + 1; end
        
        TF = TF + 1; 
        c1p = c1; 
    end
end
% -------------------------------------------------------------------------
% 3. DECISION EPOCH (Classification every 80 frames)
% -------------------------------------------------------------------------

% --- FINAL FIX: Use NESTED IF statement to bypass logical AND error ---
if frame_counter >= CLASSIFICATION_EPOCH_FRAMES
    if TF > 0
        
        Feature = [LC/TF, RC/TF, MC/TF, TC];
        FeatureOut = Feature; 
        % Classification
        species_cell = predict(svmStruct, Feature);
        species = species_cell{1}; 
        
        % Store result and reset
        last_species = species;
        LC = 0; RC = 0; MC = 0; TF = 0; TC = 0; 
        frame_counter = 0;
    end
end
% --- Final Output Assignment (using stored status) ---
FatigueStatus = uint8(last_species); 
FeatureOut(1:4) = [LC/TF, RC/TF, MC/TF, TC]; % Output current frame metrics
% --- Ensure output has fixed size (20 characters) for Simulink (FIXED SIZE)
FatigueStatus_fixed = zeros(1, 20, 'uint8');
FatigueStatus_fixed(1:length(FatigueStatus)) = FatigueStatus;
FatigueStatus = FatigueStatus_fixed;
end