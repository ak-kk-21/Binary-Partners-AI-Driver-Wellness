function start_dms_app
% START_DMS_APP: Main entry function for the deployed Driver Monitoring System.
% This function initializes the necessary data and runs the Simulink model.

% --- 1. SET UP ENVIRONMENT (CRUCIAL FOR DEPLOYMENT) ---
% When deployed, files must be accessed using the 'ctfroot' function 
% to locate them inside the compiled application package.

% NOTE: This assumes your data files (.mat and .fis) were included in the 
% compiler task and are now accessible via ctfroot.

try
    % Add the project folders to the deployed path
    addpath(fullfile(ctfroot, 'Vehicle Simulation'));
    addpath(fullfile(ctfroot, 'Binary SVM Classification'));

    % --- 2. LOAD DATA (REQUIRED BY EVALIN IN YOUR EXTERNAL FUNCTIONS) ---
    % Load all data into the base workspace for the extrinsic functions to access.
    
    % NOTE: You must ensure your MATLAB functions (like textual_decision.m) 
    % are set up to handle the deployed environment. 
    
    % Create the data structures needed by the Simulink blocks
    load(fullfile(ctfroot, 'svm.mat'), 'svmStruct');
    load(fullfile(ctfroot, 'DB.mat'), 'DBL', 'DBR', 'DBM');

    % Define the 'dim' variable
    dim = [30 60; 30 60; 40 65]; 
    
    % --- 3. RUN SIMULINK MODEL ---
    % Open and run the model non-interactively
    open_system('v1.slx');
    
    % Set simulation parameters (optional: for faster startup)
    set_param('v1', 'StopTime', 'inf');
    set_param('v1', 'FastRestart', 'on');
    
    % Start the simulation
    sim('v1');

catch ME
    % Display any errors in the deployed environment
    disp(['DMS Application Error: ', ME.message]);
end

end