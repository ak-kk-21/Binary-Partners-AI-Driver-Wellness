clc;
clear all;
close all;
%% 
% --- UPDATED CAMERA ACQUISITION ---
% Initialize the webcam object
cam = webcam(1); % Use webcam(1) to select the first available camera

% The 'webcam' object automatically handles trigger configuration (it's continuous acquisition)
% and Frame acquisition is done using snapshot.

% Create the detector objects
faceDetector = vision.CascadeObjectDetector;   
% Initializing two separate eye detectors for increased robustness
leftEyeDetector = vision.CascadeObjectDetector('LeftEye'); 
rightEyeDetector = vision.CascadeObjectDetector('RightEye'); 
faceDetectorM = vision.CascadeObjectDetector('Mouth'); 

for ii = 1:500
    
    % Get the frame in im using snapshot
    im = snapshot(cam); 
    
    subplot(3,4,[1 2 5 6 9 10]);
    imshow(im)
    
    % Detect faces
    bbox = step(faceDetector, im); 
    
    if ~isempty(bbox);
        bbox = bbox(1,:);
        % Plot face box on the main image
        rectangle('Position',bbox,'edgecolor','r');
        
        % Crop the face region (Ic)
        Ic = imcrop(im,bbox);
        
        % Show the cropped face
        subplot(3,4,[3 4]);
        imshow(Ic)
        
        % --- Dual Eye Detection Logic ---
        [h, w, ~] = size(Ic);
        
        % 1. Define targeted search regions within the face crop (Ic)
        % Left Eye: Top-left half of the face crop
        left_search_bbox = [1, 1, round(w*0.5), round(h*0.6)];
        Ic_left_search = imcrop(Ic, left_search_bbox);
        
        % Right Eye: Top-right half of the face crop
        right_search_bbox = [round(w*0.5), 1, round(w*0.5), round(h*0.6)];
        Ic_right_search = imcrop(Ic, right_search_bbox);
        
        % 2. Detect individual eyes
        bboxL = step(leftEyeDetector, Ic_left_search);
        bboxR = step(rightEyeDetector, Ic_right_search);
        
        % Initialize variables
        Leye = []; 
        Reye = []; 
        lowest_eye_y = 0;
        eyes_detected = false;
        
        if ~isempty(bboxL) && ~isempty(bboxR)
            eyes_detected = true;
            
            % Use the first detection for simplicity
            bboxL = bboxL(1,:);
            bboxR = bboxR(1,:);
            
            % Crop the individual eyes (Leye and Reye)
            Leye = imcrop(Ic_left_search, bboxL);
            Reye = imcrop(Ic_right_search, bboxR);
            
            % 3. Calculate absolute coordinates in Ic and plot bounding boxes
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
            
            % 4. Determine blackout line for mouth detection (using the lowest point of both eyes)
            lowest_eye_y = max(left_eye_pos_in_Ic(2) + left_eye_pos_in_Ic(4), ...
                               right_eye_pos_in_Ic(2) + right_eye_pos_in_Ic(4));
            
        else
            disp('Eyes not detected')
        end
        
        if ~eyes_detected
            continue;
        end
        
        % --- Mouth Detection Logic ---
        
        % Blackout the top of the face (Ic) to prevent false mouth detection
        blackout_line = lowest_eye_y + round(h * 0.15); % Lowest Y plus 15% of face height as buffer
        if blackout_line < 1, blackout_line = 1; end
        if blackout_line > h, blackout_line = h; end
        
        Ic(1:blackout_line,:,:) = 0; 
        
        % Detect Mouth on the modified Ic
        bboxM = step(faceDetectorM, Ic); 
        
        Emouth = [];
        if ~isempty(bboxM);
            % Find the lowest mouth candidate (most likely the true mouth)
            [~, idx] = max(bboxM(:, 2)); 
            bboxM = bboxM(idx,:);

            Emouth =  imcrop(Ic,bboxM);
            
            % Plot box on the cropped face subplot
            axes(subplot(3,4,[3 4]));
            hold on;
            rectangle('Position',bboxM,'edgecolor','y');
            hold off;
        else
            disp('Mouth not detected')
        end
        
        % --- Display Results ---
        
        % Display eyes 
        subplot(3,4,7)
        imshow(Leye);
        title('Left Eye');
        
        subplot(3,4,8)
        imshow(Reye);
        title('Right Eye');
        
        % Display mouth
        subplot(3,4,[11,12]);
        if ~isempty(Emouth)
            imshow(Emouth);
        else
            % Show a blank image if no mouth was detected
            imshow(zeros(200, 300, 3, 'uint8')); 
        end
        title('Mouth');

        pause(0.00005)
    end
end

% --- CLEANUP ---
clear cam; % Release the camera object after the loop