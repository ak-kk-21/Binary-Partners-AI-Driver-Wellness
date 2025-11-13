% Title: Drowsiness Detection using Machine Learning Techniques (SVM)
% Author: Manu B.N
% Contact: manubn88@gmail.com
clc;
clear all;
close all;
%%
% Load database features (DBL, DBR, DBM) and the SVM model structure (svmStruct).
% NOTE: Ensure you have run train_svm_new.m to create the modern svm.mat file.
load DB
load svm 

% cl - Class labels
cl = {'open','close'}; 
% dim - Standard size for template matching
dim = [30 60; 30 60; 40 65];

% --- START WEBCAM ACQUISITION SETUP ---
cam = webcam(1); % Initialize the first available webcam
% --- END WEBCAM ACQUISITION SETUP ---

% objects
faceDetector = vision.CascadeObjectDetector;   
% --- FIX: Using dual eye detectors for better robustness (Replaces EyePairBig) ---
leftEyeDetector = vision.CascadeObjectDetector('LeftEye'); 
rightEyeDetector = vision.CascadeObjectDetector('RightEye'); 
faceDetectorM = vision.CascadeObjectDetector('Mouth'); 

tic
% Initialise vector
LC = 0;     % Left eye close counter
RC = 0;     % Right eye close counter
MC = 0;     % Mouth open counter (Fatigue is often associated with open mouth/yawn)
TF = 0;     % Total frame counter
TC = 0;     % Total close transitions (blink rate)
Feature = [];
c1p = 1;    % Previous state of the left eye (1=open)
species = 'Non-Fatigue'; % Initial fatigue status

for ii = 1:600
   
    im = snapshot(cam); % Get the frame
    
    imshow(im)
    
    subplot(3,4,[1 2 5 6 9 10]);
    imshow(im)
    
    % Detect faces
    bbox = step(faceDetector, im); 
    
    if ~isempty(bbox);
        bbox = bbox(1,:);
        % Plot box
        rectangle('Position',bbox,'edgecolor','r');
        
        % --- Skin Segmentation (Assumes skin_seg2.m exists) ---
        % You must ensure that the function skin_seg2.m is available.
        S = skin_seg2(im); 
        bw3 = cat(3,S,S,S);
        Iss = double(im).*bw3;
        
        Ic = imcrop(im,bbox);
        Ic1 = imcrop(Iss,bbox);
        
        subplot(3,4,[3 4]);
        imshow(uint8(Ic1)) % Display skin-segmented face
        
        % --- Dual Eye Detection Logic for Robustness ---
        [h, w, ~] = size(Ic);
        
        % Define targeted search regions within the face crop (Ic)
        left_search_bbox = [1, 1, round(w*0.5), round(h*0.6)];
        Ic_left_search = imcrop(Ic, left_search_bbox);
        right_search_bbox = [round(w*0.5), 1, round(w*0.5), round(h*0.6)];
        Ic_right_search = imcrop(Ic, right_search_bbox);
        
        % Detect individual eyes
        bboxL = step(leftEyeDetector, Ic_left_search);
        bboxR = step(rightEyeDetector, Ic_right_search);
        
        Leye_raw = []; 
        Reye_raw = []; 
        lowest_eye_y = 0;
        eyes_detected = false;
        
        if ~isempty(bboxL) && ~isempty(bboxR)
            eyes_detected = true;
            bboxL = bboxL(1,:);
            bboxR = bboxR(1,:);
            
            % Crop the individual eyes
            Leye_raw = imcrop(Ic_left_search, bboxL);
            Reye_raw = imcrop(Ic_right_search, bboxR);
            
            % Calculate absolute coordinates in Ic and plot bounding boxes
            left_eye_pos_in_Ic = [bboxL(1) + left_search_bbox(1) - 1, ...
                                  bboxL(2) + left_search_bbox(2) - 1, ...
                                  bboxL(3), bboxL(4)];
            right_eye_pos_in_Ic = [bboxR(1) + right_search_bbox(1) - 1, ...
                                   bboxR(2) + right_search_bbox(2) - 1, ...
                                   bboxR(3), bboxR(4)];
            
            % Plot the boxes on the cropped face subplot
            axes(subplot(3,4,[3 4]));
            hold on;
            rectangle('Position', left_eye_pos_in_Ic, 'edgecolor', 'y', 'LineWidth', 1);
            rectangle('Position', right_eye_pos_in_Ic, 'edgecolor', 'y', 'LineWidth', 1);
            hold off;
            
            % Determine blackout line for mouth detection (using the lowest point of both eyes)
            lowest_eye_y = max(left_eye_pos_in_Ic(2) + left_eye_pos_in_Ic(4), ...
                               right_eye_pos_in_Ic(2) + right_eye_pos_in_Ic(4));
            
        else
            disp('Eyes not detected')
        end
        
        if ~eyes_detected
            continue;
        end
        
        % Blackout the top of the face (Ic) to prevent false mouth detection
        blackout_line = lowest_eye_y + round(h * 0.15); % Lowest Y plus 15% of face height as buffer
        if blackout_line < 1, blackout_line = 1; end
        if blackout_line > h, blackout_line = h; end
        
        Ic(1:blackout_line,:,:) = 0; 
        
        % Detect Mouth
        bboxM = step(faceDetectorM, Ic); 
        
        Emouth_raw = [];
        if ~isempty(bboxM);
            % Find the lowest mouth candidate (most likely the true mouth)
            [~, idx] = max(bboxM(:, 2)); 
            bboxM = bboxM(idx,:);

            Emouth_raw =  imcrop(Ic,bboxM);
            
            % Plot box on the cropped face subplot
            axes(subplot(3,4,[3 4]));
            hold on;
            rectangle('Position',bboxM,'edgecolor','y');
            hold off;
        else
            disp('Mouth not detected')
            continue; % Skip frame if mouth not detected
        end
        
        % Assigning Leye, Reye, Emouth for feature extraction (template matching)
        Leye = Leye_raw;
        Reye = Reye_raw;
        Emouth = Emouth_raw;
        
        
        % Display edge-detected eyes (Feature visualization)
        subplot(3,4,7)
        imshow(edge(rgb2gray(Leye),'sobel'));
        title('Left Eye (Edge)');
        
        subplot(3,4,8)
        imshow(edge(rgb2gray(Reye),'sobel'));
        title('Right Eye (Edge)');
        
        Emouth3 = Emouth;
        
        % Convert to grayscale for feature extraction
        Leye = rgb2gray(Leye);
        Reye = rgb2gray(Reye);
        Emouth = rgb2gray(Emouth);
        
        % K-means clustering for Mouth segmentation
        X = Emouth(:);
        [nr1, nc1] = size(Emouth);
        % Check if X has enough elements for clustering
        if length(X) < 2
            disp('Mouth region too small for K-Means. Skipping frame.');
            continue;
        end
        cid = kmeans(double(X),2,'emptyaction','drop');
        kout = reshape(cid,nr1,nc1);
        
        subplot(3,4,[11,12]);
        
        % Segment and display the mouth region with a blue background
        Ism = zeros(nr1,nc1,3);
        Ism(:,:,3) = 255; % Blue background
        bwm = kout-1;
        bwm3 = cat(3,bwm,bwm,bwm);
        Ism(logical(bwm3)) = Emouth3(logical(bwm3));
        imshow(uint8(Ism));
        title('Mouth (K-Means)');
        
        % --- Template Matching  ---
        % You must ensure that the function match_DB.m is available.
        
        % Left eye
        Leye =  imresize(Leye,[dim(1,1) dim(1,2)]);
        c1 =match_DB(Leye,DBL);
        subplot(3,4,7)
        title(cl{c1})
        
        % Right eye
        Reye =  imresize(Reye,[dim(2,1) dim(2,2)]);
        c2 = match_DB(Reye,DBR);
        subplot(3,4,8)
        title(cl{c2})
        
        % Mouth
        Emouth =  imresize(Emouth,[dim(3,1) dim(3,2)]);
        c3 = match_DB(Emouth,DBM);
        subplot(3,4,[11,12]);
        title(cl{c3})
        
        
        % --- Feature Accumulation ---
        if c1 == 2 % Left eye classified as 'close'
            LC = LC+1;
            if c1p == 1 % Transition from 'open' to 'close'
                TC = TC+1;
            end
        end
        if c2==2 % Right eye classified as 'close'
            RC = RC+1;
        end
        if c3 == 1 % Mouth classified as 'open' (using the template label index)
            MC = MC + 1;
        end
        
        TF = TF + 1; 
        
        % --- Decision Epoch ---
        toc
        if toc > 8 % Run classification every 8 seconds
            Feature = [LC/TF RC/TF MC/TF TC];
            
            % --- Using 'predict' for the modern ClassificationSVM object ---
            species_cell = predict(svmStruct, Feature);
            species = species_cell{1}; % Extract the string label
            
            disp(['Classification Result: ' species]);
            
            tic % Reset timer
            % Reset counters
            LC = 0; RC = 0; MC = 0; TF = 0; TC = 0; 
        end
        
        % --- Display Result and Alert ---
        subplot(3,4,[1 2 5 6 9 10]);
        if strcmpi(species,'Fatigue')
            text(20,20,species,'fontsize',14,'color','r','Fontweight','bold')
            beep;
        else
            text(20,20,species,'fontsize',14,'color','g','Fontweight','bold')
        end
        
        c1p = c1; % Update previous state
        pause(0.00005)
    end
end

% --- CLEANUP ---
clear cam; % Release the camera object after the loop