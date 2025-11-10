function c1 =match_DB(Leye,DBL)
% This function compares the input image (Leye) against the stored templates 
% in DBL (DBL{1} = Open template, DBL{2} = Closed template) using correlation.

% MS - Match Score
MS = zeros(1, 2); % Initialize score array for [Open, Closed] states

% --- Compare against OPEN Template (Index 1) ---
% The template database is a 1D cell array: DBL{index}.
It_open = DBL{1}; 

if ~isempty(It_open)
    % Calculate correlation coefficient against the Open template
    MS(1) = corr2(It_open, Leye);
end

% --- Compare against CLOSED Template (Index 2) ---
% NOTE: This template is likely the all-black image from the capture script.
It_closed = DBL{2}; 

if ~isempty(It_closed)
    % Calculate correlation coefficient against the Closed template
    MS(2) = corr2(It_closed, Leye);
end

% Decide about the condition
% c1 = 1 means the image is closer to the Open template (Non-Fatigue)
% c1 = 2 means the image is closer to the Closed template (Fatigue)
[~, c1] = max(MS);

% If both scores are zero (or equal), max will choose the first index (Open/1)
if MS(1) == 0 && MS(2) == 0
    c1 = 1; 
end

end