function output_message = textual_decision(risk_score)
% textual_decision: Converts the 0-1 risk score into a descriptive text message.

% Define fixed size output string for Code Generation compliance
output_message = zeros(1, 30, 'uint8'); % Initialize as numeric (ASCII) zeros

if risk_score <= 0.3
    msg = 'Driver is Alert';
elseif risk_score <= 0.7
    msg = 'Monitor Driver / Suggest Break';
else % risk_score > 0.7
    msg = 'Driver is Fatigued - ALARM';
end

% Assign the message to the fixed-size output (using uint8 conversion)
output_message(1:length(msg)) = uint8(msg);

end
function output_message = textual_decision_wrapper(risk_score)
% textual_decision_wrapper: Calls the external function for safety.
    
    % Define the external function (required for code generation)
    coder.extrinsic('textual_decision');
    
    % Pre-allocate output size (MANDATORY: must match the size in textual_decision.m)
    output_message = zeros(1, 30, 'uint8');

    % Call the external function
    output_message = textual_decision(risk_score);
end