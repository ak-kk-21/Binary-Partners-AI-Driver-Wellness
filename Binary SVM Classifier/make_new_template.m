% Title: Template Capture for Personalized Template Matching
clc;
clear all;
close all;

%% Configuration and Setup
dim = [30 60; 30 60; 40 65]; % Target template dimensions

% Initialize Webcam and Detectors
cam = webcam(1); 
faceDetector = vision.CascadeObjectDetector;   
leftEyeDetector = vision.CascadeObjectDetector('LeftEye'); 
rightEyeDetector = vision.CascadeObjectDetector('RightEye'); 
faceDetectorM = vision.CascadeObjectDetector('Mouth'); 

% Flags to track successful capture
Leye_open_captured = false;
Reye_open_captured = false;
Mouth_neutral_captured = false;

DBL = {}; % Left Eye Templates: Index 1 = Open, Index 2 = Closed
DBR = {}; % Right Eye Templates: Index 1 = Open, Index 2 = Closed
DBM = {}; % Mouth Templates: Index 1 = Open (Yawn), Index 2 = Neutral

disp('----------------------------------------------------');
disp('Starting Template Capture.');
disp('Step 1: Look directly at the camera with eyes WIDE OPEN.');
disp('Press any key to capture once the boxes are stable.');
disp('----------------------------------------------------');

% Wait for user prompt to capture
pause_for_capture = true;

while ~(Leye_open_captured && Reye_open_captured && Mouth_neutral_captured)
    
    im = snapshot(cam); 
    
    % Display current status
    status_text = {
        'STATUS:',
        ['Left Eye (Open): ', char(Leye_open_captured + '0')],
        ['Right Eye (Open): ', char(Reye_open_captured + '0')],
        ['Mouth (Neutral): ', char(Mouth_neutral_captured + '0')]
    };
    
    im_display = im;
    
    % Use text to show instructions/status on the image
    text(20, 20, status_text, 'FontSize', 14, 'Color', 'w', 'BackgroundColor', 'k');
    imshow(im_display);
    drawnow;
    
    bbox = step(faceDetector, im); 
    
    if ~isempty(bbox);
        bbox = bbox(1,:);
        Ic = imcrop(im,bbox);
        [h, w, ~] = size(Ic);
        
        % --- Dual Eye Detection ---
        left_search_bbox = [1, 1, round(w*0.5), round(h*0.6)];
        Ic_left_search = imcrop(Ic, left_search_bbox);
        right_search_bbox = [round(w*0.5), 1, round(w*0.5), round(h*0.6)];
        Ic_right_search = imcrop(Ic, right_search_bbox);
        
        bboxL = step(leftEyeDetector, Ic_left_search);
        bboxR = step(rightEyeDetector, Ic_right_search);
        
        if ~isempty(bboxL) && ~isempty(bboxR)
            
            % Crop raw eyes
            Leye_raw = imcrop(Ic_left_search, bboxL(1,:));
            Reye_raw = imcrop(Ic_right_search, bboxR(1,:));
            
            % Plot boxes on the main image for user feedback (omitted for brevity)
            
            % Blackout top for mouth detection
            lowest_eye_y = max(bboxL(1,2) + bboxL(1,4), bboxR(1,2) + bboxR(1,4));
            blackout_line = lowest_eye_y + round(h * 0.15); 
            Ic(1:blackout_line,:,:) = 0; 

            % Detect Mouth
            bboxM = step(faceDetectorM, Ic); 
            
            if ~isempty(bboxM);
                [~, idx] = max(bboxM(:, 2)); 
                Emouth_raw = imcrop(Ic,bboxM(idx,:));
            else
                Emouth_raw = []; 
            end

            % --- Capture Logic ---
            if pause_for_capture 
                % Wait for key press to capture the first set
                pause; 
                pause_for_capture = false;
            end
            
            if ~Leye_open_captured 
                % Capture Left Eye (Open)
                Leye = rgb2gray(imresize(Leye_raw,[dim(1,1) dim(1,2)]));
                DBL{1} = Leye;
                Leye_open_captured = true;
                disp('Captured Left Eye (Open).');
            end

            if ~Reye_open_captured 
                % Capture Right Eye (Open)
                Reye = rgb2gray(imresize(Reye_raw,[dim(2,1) dim(2,2)]));
                DBR{1} = Reye;
                Reye_open_captured = true;
                disp('Captured Right Eye (Open).');
            end
            
            if ~Mouth_neutral_captured && ~isempty(Emouth_raw)
                % Capture Mouth (Neutral/Closed) - Assumed state 2
                Emouth = rgb2gray(imresize(Emouth_raw,[dim(3,1) dim(3,2)]));
                DBM{2} = Emouth;
                Mouth_neutral_captured = true;
                disp('Captured Mouth (Neutral).');
            end
        end
    end
end

% --- CLEANUP ---
clear cam; 
close all;

%% Phase 2: Create Mock Closed/Yawn Templates and Save DB
% Since we can't guarantee a closed eye/yawn template capture, we must assume 
% standard black templates for the 'closed' state and blank for the 'yawn' state 
% or rely on the existing templates for these.

if length(DBL) < 2
    % Mock Closed Eye (Template 2) - This must be replaced with a real closed eye image.
    DBL{2} = zeros(dim(1,1), dim(1,2), 'uint8');
    disp('Warning: Used black image for Left Eye (Closed) template.');
end

if length(DBR) < 2
    % Mock Closed Eye (Template 2)
    DBR{2} = zeros(dim(2,1), dim(2,2), 'uint8');
    disp('Warning: Used black image for Right Eye (Closed) template.');
end

if length(DBM) < 2
    % Mock Mouth Open (Template 1) - This must be replaced with a real yawn image.
    DBM{1} = zeros(dim(3,1), dim(3,2), 'uint8');
    disp('Warning: Used black image for Mouth (Open/Yawn) template.');
end

% Save the new template database
save('DB.mat', 'DBL', 'DBR', 'DBM');

disp('----------------------------------------------------');
disp('SUCCESS: New personalized "DB.mat" file created!');
disp('Please re-run the main detection script now.');
disp('----------------------------------------------------');