cam = webcam;          % pick first available
cam.Resolution = cam.AvailableResolutions{1};  % pick the first one
img = snapshot(cam);
imshow(img);
clear cam
