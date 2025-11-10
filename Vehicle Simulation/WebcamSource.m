classdef WebcamSource < matlab.System & ...
        matlab.system.mixin.Propagates & ...
        matlab.system.mixin.CustomIcon
    % WebcamSource System Object for Simulink
    % Captures live video from the system default webcam.

    properties(Access = private)
        CamObj % Webcam object
    end

    methods(Access = protected)
        function setupImpl(obj)
            % Perform one-time calculations, such as computing constants
            try
                obj.CamObj = webcam(1);
                % Optional: Force a specific resolution if supported
                % obj.CamObj.Resolution = '1280x720'; 
            catch ME
                error('WebcamSource:SetupFailed', ...
                      'Could not initialize webcam. Ensure it is connected and not in use by another application.');
            end
        end

        function frame = stepImpl(obj)
            % Implement algorithm. Calculate y as a function of input u and
            % discrete states.
            frame = snapshot(obj.CamObj);
        end

        function resetImpl(obj)
            % Initialize / reset discrete-state properties
        end

        function releaseImpl(obj)
            % Release resources, such as file handles
            delete(obj.CamObj);
        end

        %% Signal Dimension and Type Specifications
        function sz = getOutputSizeImpl(~)
            % MUST MATCH YOUR CAMERA OUTPUT: [Height Width Channels]
            sz = [720 1280 3]; 
        end

        function dt = getOutputDataTypeImpl(~)
            dt = 'uint8';
        end

        function cp = isOutputComplexImpl(~)
            cp = false;
        end

        function fs = isOutputFixedSizeImpl(~)
            fs = true;
        end
    end
end