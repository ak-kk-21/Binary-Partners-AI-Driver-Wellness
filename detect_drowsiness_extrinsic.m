function [FatigueStatus, FeatureOut] = detect_drowsiness_extrinsic(ImageIn)
% This function runs in standard MATLAB mode, NOT code generation mode.
% It can freely use persistent variables, complex objects, and any MATLAB function.

persistent faceDetector leftEyeDetector rightEyeDetector faceDetectorM;
persistent svmStruct DBL DBR DBM dim;
persistent LC RC MC TF TC c1p frame_counter;

% --- INITIALIZATION (First Run Only) ---
if isempty(faceDetector)
    % Initialize Detectors
    faceDetector = vision.CascadeObjectDetector;
    leftEyeDetector = vision.CascadeObjectDetector('LeftEye');
    rightEyeDetector = vision.CascadeObjectDetector('RightEye');
    faceDetectorM = vision.CascadeObjectDetector('Mouth');
    
    % Load Data DIRECTLY from workspace (allowed in extrinsic mode)
    svmStruct = evalin('base', 'svmStruct');
    DBL = evalin('base', 'DBL');
    DBR = evalin('base', 'DBR');
    DBM = evalin('base', 'DBM');
    dim = evalin('base', 'dim');
    
    LC = 0; RC = 0; MC = 0; TF = 0; TC = 0; c1p = 1;
    frame_counter = 0;
end

% ... [INSERT THE EXACT SAME DETECTION LOGIC FROM PREVIOUS VERSIONS HERE] ...
% For brevity, I will summarize the logic, but you MUST paste the full
% body of the detection loop here. It is identical to what we had before.
% ...

% --- DUMMY OUTPUT FOR NOW TO PROVE IT WORKS ---
% Replace this with the full logic once the connection is verified.
FatigueStatus = uint8('Non-Fatigue         '); % 20 chars
FeatureOut = [0 0 0 0]; 

end