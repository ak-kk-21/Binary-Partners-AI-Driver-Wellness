classdef (Sealed) webcam < matlabshared.testmeas.CustomDisplay & matlab.mixin.SetGet & dynamicprops...
        & matlab.webcam.internal.WebcamDataUtilityHelper
    %    WEBCAM creates webcam object to acquire frames from your webcam.
    %    CAMOBJ = WEBCAM returns a webcam object, CAMOBJ, that acquires images
    %    from the specified webcam. By default, this selects the first
    %    available webcam returned by WEBCAMLIST.
    %
    %    CAMOBJ = WEBCAM(DEVICENAME) returns a webcam object, CAMOBJ, for
    %    webcam with the specified name, DEVICENAME. The webcam name can be
    %    found using the function WEBCAMLIST.
    %
    %    CAMOBJ = WEBCAM(DEVICEINDEX) returns a webcam object, CAMOBJ, for
    %    webcam with the specified device index, DEVICEINDEX. The webcam device
    %    index is the index into the cell array returned by WEBCAMLIST.
    %
    %    CAMOBJ = WEBCAM(..., P1, V1, P2, V2,...) constructs the webcam object,
    %    CAMOBJ, with the specified property values. If an invalid property
    %    name or property value is specified, the webcam object is not created.
    %
    %    Creating WEBCAM object obtains exclusive access to the webcam.
    %
    %    SNAPSHOT method syntax:
    %
    %    IMG = snapshot(CAMOBJ) acquires a single frame from the webcam.
    %
    %    [IMG, TIMESTAMP] = snapshot(CAMOBJ) returns the frame, IMG, and the
    %    acquisition timestamp, TIMESTAMP.
    %
    %    WEBCAM methods:
    %
    %    snapshot     - Acquire a single frame from the webcam.
    %    preview      - Activate a live image preview window.
    %    closePreview - Close live image preview window.
    %
    %    WEBCAM properties:
    %
    %    Name                 - Name of the webcam.
    %    Resolution           - Resolution of the acquired frame.
    %    AvailableResolutions - Cell array of list of available resolutions.
    %
    %    The WEBCAM interface also supports the dynamic properties of the webcam
    %    that we can access programmatically. Some of these dynamic properties
    %    are Brightness, Contrast, Hue, Exposure etc. The presence of these
    %    properties in the WEBCAM object depends on the webcam that you connect
    %    to. Dynamic properties are not supported when using webcam in MATLAB
    %    Online.
    %
    %    Example:
    %       % Construct a webcam object
    %       camObj = webcam;
    %
    %       % Preview a stream of image frames.
    %       preview(camObj);
    %
    %       % Acquire and display a single image frame.
    %       img = snapshot(camObj);
    %       imshow(img);
    %
    %    See also WEBCAMLIST, SNAPSHOT, PREVIEW

    % Copyright 2013-2024 The MathWorks, Inc.

    properties(Dependent, GetAccess = public, SetAccess = private)
        %   Name Specifies the name of the webcam.
        %   The Name property cannot be modified once the object is created
        %   and is read only.
        Name
    end

    properties(GetAccess = {?matlab.webcam.internal.WebcamDataUtilityParser}, SetAccess = private, Hidden)
        WebcamImpl
    end

    properties(Dependent)
        Resolution
    end

    properties(Dependent, GetAccess = public, SetAccess = private)
        AvailableResolutions
    end

    properties(Dependent, GetAccess = public, SetAccess = private, Hidden)
        IsBinaryChannelUsed
        UniqueID
    end

    properties(Dependent, Access = public, Hidden)
        EnableMessageService
    end

    properties(Constant,Access = private)
        % Allowed values for mode properties
        ModeOptions = ["auto", "manual"]
        % Common webcam properties
        CommonProperties = ["Name","Resolution","AvailableResolutions"]
    end


    properties (SetAccess = private, GetAccess = ?matlab.webcam.internal.PropertyInfo)
        % Store the range of permissible values for dynamic properties
        PropertyRange
        % Store the default values of properties provided by the camera
        PropertyDefaults
        % Store the property step values provided by the camera
        PropertyStepSizes
    end

    methods(Hidden,Access=public)
        function webcamController = getCameraController(obj)
            % Return the controller for the current implementation of webcam
            webcamController = obj.WebcamImpl.getCameraController;
        end
    end

    methods(Hidden)
        function obj = webcam(varargin)
            % Create a webcamDesktop object or webcamOnline object based on
            % where this is running. Also add dynamic properties if this is
            % a webcamDesktop object.
            try
                % Initialize clean up function
                c = onCleanup(@() integrateData(obj,varargin{:}));
                % Register the message catalog resource location with
                % MATLAB
                matlab.webcam.internal.Utility.loadResources();
                % Initialize property group for custom object display
                obj.PropertyGroupList = cellstr(obj.CommonProperties);
                obj.PropertyGroupNames = "";
                dynPropKeys = {};

                if matlab.webcam.internal.Utility.isMATLABDesktop
                    obj.WebcamImpl = matlab.webcam.internal.webcamDesktop(varargin{:});
                    dynProps = obj.WebcamImpl.getDynamicProperties();
                    dynPropKeys = dynProps.keys;
                    dynPropValues = dynProps.values;
                    for propCount=1:length(dynProps)
                        prop = addprop(obj,dynPropKeys{propCount});
                        obj.(dynPropKeys{propCount}) = dynPropValues{propCount};
                        prop.SetAccess = 'public';
                        prop.Dependent = true;
                        prop.AbortSet = 1;
                        prop.SetMethod = @(obj, value) obj.setDynamicProperty(prop.Name, value);
                        prop.GetMethod = @(obj) obj.WebcamImpl.getDynamicProperty(prop.Name);

                        % Add the property name as a field to the structs
                        % PropertyRange, PropertyDefault and
                        % PropertyStepSize querying channel's properties
                        if ~endsWith(prop.Name, 'Mode')
                            obj.PropertyRange.(prop.Name) = obj.WebcamImpl.getPropertyRange(prop.Name);
                            obj.PropertyDefaults.(prop.Name) = obj.WebcamImpl.getPropertyDefault(prop.Name);
                            obj.PropertyStepSizes.(prop.Name) = obj.WebcamImpl.getPropertyStepSize(prop.Name);
                        else
                            obj.PropertyRange.(prop.Name) = obj.ModeOptions;
                            obj.PropertyDefaults.(prop.Name) = obj.ModeOptions(1);
                            obj.PropertyStepSizes.(prop.Name) = [];
                        end
                    end
                else
                    % This is running in MATLAB Online, create a webcamOnline
                    % object.
                    obj.WebcamImpl = matlab.webcam.internal.webcamOnline(varargin{:});
                end

                % Append alphabetically sorted list of dynamic property
                % names to the custom display's property group list
                obj.PropertyGroupList = {[obj.PropertyGroupList,...
                    string(sort(dynPropKeys))]};

                % Wait for the camera settings to take effect if users have
                % provided camera properties as NV pairs
                if(nargin > 2)
                    pause(0.5);
                end

                % Disable "all methods" custom display footer hyperlink
                obj.ShowAllMethodsInFooter = false;
                obj.ShowAllPropertiesInFooter = false;
            catch e
                % If there were errors creating a webcamOnline or
                % webcamDesktop object, error out.
                integrateErrorKey(obj, e.identifier);
                throwAsCaller(e);
            end
        end
    end

    % GET/SET methods
    methods
        function value = get.Name(obj)
            value = obj.WebcamImpl.Name;
        end

        function value = get.Resolution(obj)
            value = obj.WebcamImpl.Resolution;
        end

        function value = get.AvailableResolutions(obj)
            value = obj.WebcamImpl.AvailableResolutions;
            % Sort available resolutions based on total pixels
            dimensions = cellfun(@(x)strsplit(x,"x"),value,'UniformOutput',false);
            pixels = cellfun(@(x) str2double(x{1})*str2double(x{2}),dimensions,'UniformOutput',false);
            [~,index] = sort([pixels{:}],"descend");
            value = value(index);
        end

        function value = get.IsBinaryChannelUsed(obj)
            value = obj.WebcamImpl.IsBinaryChannelUsed;
        end

        function value = get.UniqueID(obj)
            value = obj.WebcamImpl.UniqueID;
        end

        function value = get.EnableMessageService(obj)
            value = obj.WebcamImpl.EnableMessageService;
        end

        function set.Resolution(obj,value)
            try
                % Initialize clean up function
                if isvalid(obj)
                    c = onCleanup(@() integrateData(obj,'Resolution', value));
                end
                obj.WebcamImpl.setResolution(value);
            catch excep
                if isvalid(obj)
                    integrateErrorKey(obj, excep.identifier);
                end
                throwAsCaller(excep);
            end
        end

        function set.EnableMessageService(obj,value)
            obj.WebcamImpl.EnableMessageService = value;
        end

        function setDynamicProperty(obj,propName,value)
            % Update the dynamic property of the webcam to the provided
            % value
            try
                % Initialize clean up function
                if isvalid(obj)
                    c = onCleanup(@() integrateData(obj,propName,value));
                end
                % Call the internal property setter to validate the input
                % and update the property value
                obj.WebcamImpl.setDynamicProperty(propName, value);
            catch excep
                if isvalid(obj)
                    integrateErrorKey(obj, excep.identifier);
                end
                throwAsCaller(excep);
            end
        end

        % Generic set method
        function varargout = set(obj, varargin)
            try
                if (nargin==1) || (nargin==2 && ~isstruct(varargin{1}))
                    out = obj.WebcamImpl.set(varargin{:});
                    varargout = {out};
                else
                    set(obj.WebcamImpl,varargin{:});
                end
            catch e
                throwAsCaller(e);
            end
        end

        function value = get(obj, varargin)
            try
                value = obj.WebcamImpl.get(varargin{:});
            catch e
                throwAsCaller(e);
            end
        end
    end

    % Public Methods
    methods
        % Preview can return an hImage in desktop, but currently does not
        % return anything in MATLAB Online
        function varargout = preview(obj,varargin)
            try
                % Initialize clean up function
                if (isa(obj,'webcam') && isvalid(obj))
                    c = onCleanup(@() integrateData(obj,varargin{:}));
                end

                if ~matlab.webcam.internal.Utility.isMATLABDesktop
                    if (nargout ~= 0)
                        throwAsCaller(MException('MATLAB:webcam:TooManyOutputs', 'Too many output arguments.'));
                    end
                    % If the AWS instance is disconnected, then when the session comes back, check to see if the WebcamImpl exists.
                    if isempty(obj.WebcamImpl)
                        error('MATLAB:webcam:invalidObject', message('MATLAB:webcam:webcam:invalidObject').getString);
                    end
                    obj.WebcamImpl.preview();
                else
                    nargoutchk(0,1);
                    % Return an output only if requested.
                    if (nargout > 0)
                        varargout = obj.WebcamImpl.preview(varargin{:});
                        varargout = {varargout};
                    else
                        obj.WebcamImpl.preview(varargin{:})
                    end
                end
            catch e
                if (strcmp(e.identifier,'MATLAB:unassignedOutputs') && ~(matlab.webcam.internal.Utility.isMATLABDesktop))
                    % MATLAB Online does not return an output argument for
                    % preview, so don't error out.
                else
                    if (isa(obj,'webcam') && isvalid(obj))
                        integrateErrorKey(obj, e.identifier);
                    end
                    throwAsCaller(e);
                end
            end
        end

        function [image, timestamp] = snapshot(obj)
            try
                % Initialize clean up function
                if isvalid(obj)
                    c = onCleanup(@() integrateData(obj));
                end
                % If the AWS instance is disconnected, then when the session comes back, check to see if the WebcamImpl exists.
                if isempty(obj.WebcamImpl)
                    error('MATLAB:webcam:invalidObject', message('MATLAB:webcam:webcam:invalidObject').getString);
                end
                [image, timestamp]  = obj.WebcamImpl.snapshot;
            catch e
                if isvalid(obj)
                    integrateErrorKey(obj, e.identifier);
                end
                throwAsCaller(e);
            end
        end

        function closePreview(obj)
            try
                % Initialize clean up function
                if isvalid(obj)
                    c = onCleanup(@() integrateData(obj));
                end
                obj.WebcamImpl.closePreview;
            catch e
                if isvalid(obj)
                    integrateErrorKey(obj, e.identifier);
                end
                throwAsCaller(e);
            end
        end

        function info = propertyInfo(obj,props)
            % Function to return metadata for webcam properties

            arguments
                obj     (1,1) webcam
                % Validate all input property name(s) to be non-empty string values.
                % Get all hardware properties, if none specified.
                props   (1,:) string {mustBeText, mustBeNonzeroLengthText, mustBeNonempty} = string(obj.PropertyGroupList{:})
            end

            % Initialize clean up function
            if isvalid(obj)
                c = onCleanup(@() integrateData(obj,props));
            end

            try
                % Create 1xN array of propertyInfo objects; where N is the
                % number of properties
                numProps = length(props);
                info = repmat(matlab.webcam.internal.PropertyInfo.empty,1,numProps);
                for propIndex = 1:numProps
                    property = string(props(propIndex));
                    info(propIndex) = matlab.webcam.internal.PropertyInfo(obj,property);
                end
            catch e
                if isvalid(obj)
                    integrateErrorKey(obj, e.identifier);
                end
                throwAsCaller(e);
            end
        end
    end

    % Public Hidden Methods that will be disabled
    methods(Access = public, Hidden)

        function c = horzcat(varargin)
            %HORZCAT Horizontal concatenation of webcam objects.

            if (nargin == 1)
                c = varargin{1};
            else
                error('MATLAB:webcam:noconcatenation', message('MATLAB:webcam:webcam:noconcatenation').getString);
            end
        end
        function c = vertcat(varargin)
            %VERTCAT Vertical concatenation of webcam objects.

            if (nargin == 1)
                c = varargin{1};
            else
                error('MATLAB:webcam:noconcatenation', message('MATLAB:webcam:webcam:noconcatenation').getString);
            end
        end
        function c = cat(varargin)
            %CAT Concatenation of webcam objects.
            if (nargin > 2)
                error('MATLAB:webcam:noconcatenation', message('MATLAB:webcam:webcam:noconcatenation').getString);
            else
                c = varargin{2};
            end
        end

        % Hidden methods from the hgsetget super class.
        function res = eq(obj, varargin)
            res = isequal(obj, varargin{:});
        end
        function res = ge(obj, varargin)
            res = ge@handle(obj, varargin{:});
        end
        function res = gt(obj, varargin)
            res = gt@handle(obj, varargin{:});
        end
        function res = le(obj, varargin)
            res = le@handle(obj, varargin{:});
        end
        function res = lt(obj, varargin)
            res = lt@handle(obj, varargin{:});
        end
        function res = ne(obj, varargin)
            res = ne@handle(obj, varargin{:});
        end
        function res = findobj(obj, varargin)
            res = findobj@handle(obj, varargin{:});
        end
        function res = findprop(obj, varargin)
            res = findprop@handle(obj, varargin{:});
        end
        function res = addlistener(obj, varargin)
            res = addlistener@handle(obj, varargin{:});
        end
        function res = notify(obj, varargin)
            res = notify@handle(obj, varargin{:});
        end

        % Hidden methods from the dynamic proper superclass
        function res = addprop(obj, varargin)
            res = addprop@dynamicprops(obj, varargin{:});
        end

        % Override isequal method for webcam
        function res = isequal(obj1, obj2)
            p1 = properties(obj1);
            p2 = properties(obj2);
            res = true;
            if(~isa(obj2,'webcam') || ~isequal(p1,p2))
                res = false;
                return;
            end
            for idx=1:length(p1)
                if(~isequal(obj1.(p1{idx}),obj1.(p2{idx})))
                    res = false;
                    return;
                end
            end
        end

        % Override KeyMatch method for Webcam
        function res = keyMatch(obj1, obj2)
            res = true;
            if(~isa(obj2,'webcam') || ~keyMatch(obj1.UniqueID, obj2.UniqueID))
                res = false;
                return;
            end
        end

        % Override KeyHash method for Webcam
        function hashCode = keyHash(obj)
            % Create a unique hash key with webcam's unique ID
            hashCode = keyHash(obj.WebcamImpl.UniqueID);
        end

        function delete(obj)
            try
                if(~isempty(obj.WebcamImpl))
                    % Reduce the resource count every time the destructor is
                    % called and call the WebcamImpl destructor only when the
                    % resource count becomes zero
                    obj.WebcamImpl.ResourceCount = obj.WebcamImpl.ResourceCount-1;
                    if ~isempty(obj.WebcamImpl) && obj.WebcamImpl.ResourceCount == 0
                        obj.WebcamImpl.delete();
                    end
                end
            catch e
                throwAsCaller(e);
            end
        end

        function out = saveobj(obj, varargin)
            try
                if ~matlab.webcam.internal.Utility.isMATLABDesktop
                    out = obj.WebcamImpl.saveOnlineObj;
                else
                    out = obj.WebcamImpl.saveobj(varargin{:});
                end
            catch e
                throwAsCaller(e);
            end
        end
    end

    methods(Static, Hidden)
        % load and save methods
        function obj = loadobj(inStruct)
            try
                if matlab.webcam.internal.Utility.isMATLABDesktop
                    obj = matlab.webcam.internal.webcamDesktop.loadobj(inStruct);
                else
                    obj = matlab.webcam.internal.webcamOnline.loadOnlineObj(inStruct);
                end
            catch e
                throwAsCaller(e);
            end
        end
    end
end

% LocalWords:  CAMOBJ WEBCAMLIST DEVICENAME DEVICEINDEX AWS noconcatenation
