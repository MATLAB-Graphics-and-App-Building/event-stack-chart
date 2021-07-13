classdef eventStackChart < matlab.graphics.chartcontainer.ChartContainer & ...
        matlab.graphics.chartcontainer.mixin.Colorbar
    %eventStackChart Visualize the duration of events by time-of-day or
    %   time-of-year.
    %
    %   eventStackChart(startTimes, endTimes) creates a line segment for
    %   each pair of values in startTimes and endTimes. The line's length
    %   is determined by the duration between the times, and the line is
    %   positioned by the event's time-of-day or time-of-year over an
    %   arbitrary day or year time period.
    %
    %   eventStackChart(startTimes, durations) creates a line segment for
    %   each pair of values in startTimes and durations in the same manner
    %   described above. endTimes are computed using the values in durations.
    %
    %   eventStackChart(___, timePeriod) specifies the time period over
    %   which events should be arranged, either 'Day' or 'Year'. Time
    %   period is chosen automatically when not specified based on the
    %   maximum duration of events described by startTimes and endTimes.
    %
    %   eventStackChart(___, eventNames) specifies names for each event.
    %   eventNames must have the same number of elements as StartTimes.
    %
    %   eventStackChart(___, Name, Value) specifies additional options for
    %   the chart using one or more name-value pair arguments. Specify the
    %   options after all other input arguments.
    %
    %   By default, events are arranged vertically and given a colormapped
    %   color according to their duration. Specify 'YData' and/or
    %   'ColorData' to change this.
    %
    %   eventStackChart(target,___) plots into target instead of GCF.
    %
    %   E = eventStackChart(___) returns the eventStackChart object. Use
    %   E to modify properties of the chart after creating it.
    
    % Copyright 2021 The MathWorks, Inc.
    
    properties
        StartTimes (1,:) datetime {mustBeFinite} = datetime.empty()
        EndTimes (1,:) datetime {mustBeFinite} = datetime.empty()
        EventNames (1,:) string = strings(1,0) % used for data tips
        
        Title (:,1) string = ""
        XLabel (:,1) string = ""
        YLabel (:,1) string = ""
        ColorbarLabel (:,1) string = ""
        
        Colormap (:,3) double {mustBeNonempty, mustBeInRange(Colormap,0,1)} = get(groot, 'factoryFigureColormap')
        ColorMethod (1,1) string {mustBeMember(ColorMethod,["colormapped","solid"])} = "colormapped"
        Marker (1,:) char {mustBeMember(Marker,{'o','*','+','p','h','^','v','>','<','x','+','s','d','.','|','_','none'})} = 'none'
        LineWidth (1,1) {mustBeNumeric, mustBePositive} = 1.5
    end
    
    properties (Dependent)
        YData (1,:) {mustBeNumeric, mustBeFinite}
        ColorData (1,:) {mustBeNumeric, mustBeFinite}
        TimePeriod (1,1) string {mustBeMember(TimePeriod, ["day" "year"])} = "day"
        XLimits (1,2) datetime {mustBeLimits}
        YLimits (1,2) {mustBeNumeric, mustBeLimits}
    end
    
    properties (Access = protected)
        % Used for saving to .fig files
        ChartState = []
    end
    
    properties(SetAccess = private, Transient)
        EventDurations (1,:) duration
    end
    
    properties(Access=private, Transient, NonCopyable)
        LineObjects (:,1) matlab.graphics.chart.primitive.Line
        
        RecomputeData (1,1) logical = false
        UpdateDataTipLabels (1,1) logical = false
        
        XDataForPlot
        YDataForPlot
        
        StartTimes_Normalized
        EndTimes_Normalized
        
        TimePeriodStart
        TimePeriodEnd
        
        YData_I
        YDataMode (1,1) string {mustBeMember(YDataMode, ["auto", "manual"])} = "auto"
        
        ColorData_I
        ColorDataMode (1,1) string {mustBeMember(ColorDataMode, ["auto", "manual"])} = "auto"
        
        TimePeriod_I
        TimePeriodMode (1,1) string {mustBeMember(TimePeriodMode, ["auto", "manual"])} = "auto"
        
        TimeZoneIgnoredWarning (1,1) logical = false
    end
    
    methods
        function obj = eventStackChart(varargin)
            
            % Initialize list of arguments
            args = varargin;
            leadingArgs = cell(0);
            
            % Check if the first input argument is a graphics object to use as parent.
            if ~isempty(args) && isa(args{1},'matlab.graphics.Graphics')
                % eventStackChart(parent, ___)
                leadingArgs = args(1);
                args = args(2:end);
            end
            
            % Check for positional data argument syntaxes:
            %     eventStackChart(startTimes, endTimes)
            %     eventStackChart(startTimes, durations)
            if numel(args) >= 2 && isdatetime(args{1})
                
                starttime = args{1}(:); % assure column vector
                
                if numel(starttime) ~= numel(args{2})
                    error('eventStackChart:InputSizeMismatch','Both data inputs must be vectors of the same length.');
                elseif isdatetime(args{2})
                    % eventStackChart(startTimes, endTimes)
                    endtime = args{2}(:);
                elseif isduration(args{2})
                    % eventStackChart(startTimes, duration)
                    endtime = starttime + args{2}(:);
                else
                    error('eventStackChart:InvalidSecondInput','Second data value must be datetime or duration.')
                end
                
                % verify that all starttimes occur before endtimes
                if any((endtime - starttime) < 0)
                    error('eventStackChart:NegativeDurations','Events cannot have negative durations.')
                end
                
                leadingArgs = [leadingArgs {'StartTimes', starttime, 'EndTimes', endtime}];
                args = args(3:end);
                
                % check for other positional arguments
                if ~isempty(args)
                    if ismember(string(lower(args{1})),["year","day"])
                        % eventStackChart( ... , yearOrDayFlag)
                        
                        leadingArgs = [leadingArgs {'TimePeriod',args{1}}];
                        args = args(2:end);
                    end
                    if (isstring(args{1}) || iscellstr(args{1})) && ...
                            numel(args{1}) == numel(starttime)
                        % eventStackChart( ... , eventNames)
                        
                        leadingArgs = [leadingArgs {'EventNames',args{1}}];
                        args = args(2:end);
                    end
                end
            end
            
            if mod(numel(args),2) == 1
                error('eventStackChart:InvalidInputs','Invalid inputs. Expected pairs of name-value arguments.')
            end
            
            % Combine positional arguments with name/value pairs.
            args = [leadingArgs args];
            
            % Call superclass constructor method
            obj@matlab.graphics.chartcontainer.ChartContainer(args{:});
        end
        
    end
    
    methods(Access = protected)
        
        function setup(obj)
            % Create the axes
            ax = getAxes(obj);
            box(ax,'on');

            % plot empty data to initialize XAxis as datetime
            hold(ax,'on');
            plot(ax,NaT,NaN); 
            hold(ax,'off');
            
            ax.XAxis.TickLabelFormatMode = 'manual';
            
            % Customize Axes Toolbar & Default Interactions
            axtoolbar(ax, {'export' 'datacursor' 'pan' 'zoomin' 'zoomout' 'restoreview'});
            ax.Interactions = [ dataTipInteraction regionZoomInteraction ...
                rulerPanInteraction zoomInteraction];
            
            % Call the load method in case of loading from a fig file
            loadstate(obj);
        end
        
        function update(obj)
            if obj.RecomputeData
                updateChartData(obj);
            end
            
            % set title and labels
            title(getAxes(obj), obj.Title);
            xlabel(getAxes(obj), obj.XLabel);
            ylabel(getAxes(obj), obj.YLabel);
            if obj.ColorbarVisible
                ylabel(obj.getAxes.Colorbar, obj.ColorbarLabel); % label for colorbar
            end
            
            % set colors of lines
            if(string(obj.ColorMethod) == "colormapped")
                if numel(obj.ColorData_I) ~= numel(obj.StartTimes)
                    warning('eventStackChart:ColorDataSize','ColorData must have the same number of elements as StartTimes.');
                    return;
                end
                updateColormappedColors(obj);
            else
                set(obj.LineObjects,'Color',obj.Colormap(1,:));
                set(obj.LineObjects,'MarkerFaceColor',obj.Colormap(1,:));
                obj.getAxes.CLimMode = 'auto';
            end
            
            % set marker & linewidth
            set(obj.LineObjects,'Marker',obj.Marker);
            set(obj.LineObjects,'LineWidth',obj.LineWidth);
            
            % set EventNames for use in data tips
            if obj.UpdateDataTipLabels
                if ~isempty(obj.EventNames) && any(obj.EventNames ~= "")
                    if numel(obj.EventNames) ~= numel(obj.LineObjects)
                        warning('eventStackChart:EventNamesSize','EventNames must have the same number of elements as StartTimes.');
                        return;
                    end
                    for n = 1:numel(obj.LineObjects)
                        thisLine = obj.LineObjects(n);
                        thisEvent = repmat(obj.EventNames(n), 1, numel(thisLine.XData));
                        thisLine.DataTipTemplate.DataTipRows(3) = dataTipTextRow('Event',thisEvent);
                    end
                end
                obj.UpdateDataTipLabels = false;
            end
        end
        
        function propgrp = getPropertyGroups(obj)
            if ~isscalar(obj)
                propgrp = getPropertyGroups@matlab.mixin.CustomDisplay(obj);
            else
                propList = struct(...
                    'StartTimes', obj.StartTimes,...
                    'EndTimes', obj.EndTimes, ...
                    'YData', obj.YData_I, ...
                    'ColorData',obj.ColorData_I,...
                    'Colormap',obj.Colormap,...
                    'ColorMethod',obj.ColorMethod,...
                    'LineWidth',obj.LineWidth);
                propgrp = matlab.mixin.util.PropertyGroup(propList);
            end
        end
    end % end protected methods
    
    methods(Access = private)
        
        % Normalize datetime values to a given day or year, depending on 
        % the value of TimePeriod, so they can be plotted within the same 
        % range. This method also sets the datetime display format.
        function normtimes = normalizedTime(obj, times)
            normtimes = times;
            
            % For simplicity, time zones are simply ignored.
            tz = normtimes.TimeZone;
            if ~isempty(tz) || ~strcmp(tz,'') || tz ~= ""
                if ~obj.TimeZoneIgnoredWarning
                    % Only warn the first time this is encountered.
                    warning('TimeZone is being ignored');
                    obj.TimeZoneIgnoredWarning = true;
                end
                normtimes.TimeZone = '';
            end
            
            normtimes.Year = year(obj.TimePeriodStart);
            
            switch obj.TimePeriod_I
                case "day"
                    normtimes.Day = 1;
                    normtimes.Month = 1;
                    normtimes.Format = 'h:mm a';
                case "year"
                    normtimes.Format = 'dd MM, yyyy';
            end
        end
        
        function updateColormappedColors(obj)
            n = height(obj.Colormap);
            
            % rescale ColorData from 1 to number of colors in map
            scaled_vals = floor(rescale(obj.ColorData_I, 1, n+0.99));
            
            % set lines to use the new colormapped colors
            colors = obj.Colormap(scaled_vals,:);
            set(obj.LineObjects,{'Color'},num2cell(colors,2));
            set(obj.LineObjects,{'MarkerFaceColor'},num2cell(colors,2));
            clims = [min(obj.ColorData_I) max(obj.ColorData_I)];
            if clims(1) == clims(2)
                % Make sure color limits span a non-zero interval.
                clims(2) = clims(1) + 1;
            end
            obj.getAxes.CLim = clims;
        end
        
        function updateChartData(obj)
            % Check that StartTime and EndTime vectors are same size.
            if (numel(obj.EndTimes) ~= numel(obj.StartTimes))
                warning('eventStackChart:EndTimesSize','EndTimes must have the same number of elements as StartTimes.')
                return;
            end
            
            obj.EventDurations = obj.EndTimes - obj.StartTimes;
            
            % Check for negative EventDurations.
            if any(obj.EventDurations < 0)
                warning('eventStackChart:NonNegativeDurations','EndTimes must be greater than or equal to StartTimes.')
                return;
            end
            
            % Choose an appropriate TimePeriod by default.
            if obj.TimePeriodMode == "auto"
                if max(obj.EventDurations) <= days(1)
                    obj.TimePeriod_I = "day";
                else
                    obj.TimePeriod_I = "year";
                end
            end
            
            % Check for EventDurations that exceed one full TimePeriod.
            if obj.TimePeriod_I == "day"
                if any(obj.EventDurations > hours(25)) % to account for DST
                    warning('eventStackChart:InvalidTimePeriod','EndTimes must be less than one full day after StartTimes when TimePeriod set to "day". Consider setting TimePeriod to "year" instead.')
                    return;
                end
            elseif obj.TimePeriod_I == "year"
                if any(obj.EventDurations > days(366)) % to account for leap years
                    warning('eventStackChart:InvalidTimePeriod','EndTimes must be less than one full year after StartTimes.')
                    return;
                end
            end
            
            % Use EventDuration as YData if user has not specified
            % YData.
            if obj.YDataMode == "auto"
                
                % Convert EventDuration to numeric number of hours or
                % days depending on TimePeriod.
                if obj.TimePeriod_I == "day"
                    obj.YData_I = hours(obj.EventDurations);
                elseif obj.TimePeriod_I == "year"
                    obj.YData_I = days(obj.EventDurations);
                end
            end
            
            % Use YData for ColorData if user has not specified
            % ColorData.
            if obj.ColorDataMode == "auto"
                obj.ColorData_I = obj.YData_I;
            end
            
            % Compute a benchmark TimePeriodStart and TimePeriodEnd to
            % reflect the start and end of the arbitrary day or year we
            % will be plotting over.
            obj.TimePeriodStart = min(obj.StartTimes);
            obj.TimePeriodStart = normalizedTime(obj, obj.TimePeriodStart); % standardizes display format
            obj.TimePeriodStart.Hour = 0;
            obj.TimePeriodStart.Minute = 0;
            obj.TimePeriodStart.Second = 0;
            if obj.TimePeriod_I == "day"
                obj.TimePeriodEnd = obj.TimePeriodStart + days(1);
            elseif obj.TimePeriod_I == "year"
                obj.TimePeriodStart.Day = 1;
                obj.TimePeriodStart.Month = 1;
                obj.TimePeriodEnd = obj.TimePeriodStart + years(1);
            end
            
            % generate data to use to call plot
            generateDataForPlot(obj);
            
            % delete old line objects
            delete(obj.LineObjects);
            
            % replot with recomputed data
            hold(obj.getAxes,'on');
            obj.LineObjects = plot(obj.getAxes, obj.XDataForPlot', obj.YDataForPlot',...
                'MarkerSize',4);
            hold(obj.getAxes,'off');

            % set the tick label format appropriate for the TimePeriod
            if obj.TimePeriod_I == "day"
                obj.getAxes.XAxis.TickLabelFormat = 'HH:mm';
            elseif obj.TimePeriod_I == "year"
                obj.getAxes.XAxis.TickLabelFormat = 'MMM';
            end
            
            if ~isempty(obj.EventNames)
                obj.UpdateDataTipLabels = true;
            end
            
            obj.RecomputeData = false;
        end
        
        function generateDataForPlot(obj)
            
            % Normalize start and end times to be on the same day to allow
            % comparison across different days
            obj.StartTimes_Normalized = normalizedTime(obj, obj.StartTimes);
            obj.EndTimes_Normalized   = normalizedTime(obj, obj.EndTimes);
            
            % Initialize XData and YData Arrays to be used for plot objects
            obj.XDataForPlot = NaT(numel(obj.StartTimes),5);
            obj.YDataForPlot = NaN(numel(obj.StartTimes),5);
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % XData_Internal for each row is a 5 element vector:
            % [BeginningOfTimePeriod Time1 HalfwayBetweenTimes Time2 EndOfTimePeriod]
            
            % 1st value for XData vector = beginning of the time period
            obj.XDataForPlot(:,1) = obj.TimePeriodStart;
            
            % 2nd value for XData vector = event start time or end time,
            % whichever happened earlier in the day
            obj.XDataForPlot(:,2) = min([obj.EndTimes_Normalized; obj.StartTimes_Normalized],[],1);
            
            % 3rd value for XData vector = 1/2 way between start and end times
            obj.XDataForPlot(:,3) = obj.XDataForPlot(:,2) + (obj.EventDurations')/2;
            
            % 4th value for XData vector = event start time or end time,
            % whichever happened later in the day
            obj.XDataForPlot(:,4) = max([obj.EndTimes_Normalized;  obj.StartTimes_Normalized],[], 1);
            
            % 5th value for XData vector = end of the day
            obj.XDataForPlot(:,5) = obj.TimePeriodEnd;
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % YData_Internal for each row is a 5 element vector. Each element is
            % either NaN (so that no line is plotted) or the YData value for
            % that row
            
            % 2nd and 4th values for YData are always the row's YData value
            obj.YDataForPlot(:,2) = obj.YData_I;
            obj.YDataForPlot(:,4) = obj.YData_I;
            
            % When Start Time occurs after End Time ... (wrap around case)
            % 1st and 5th values for YData_Internal are the row's YData value
            % (3rd value is left as NaN)
            wrap_idx = obj.StartTimes_Normalized > obj.EndTimes_Normalized;
            obj.YDataForPlot(wrap_idx,1) = obj.YData_I(wrap_idx);
            obj.YDataForPlot(wrap_idx,5) = obj.YData_I(wrap_idx);
            
            % When Start Time occurs before End Time ... (normal case)
            % 3rd value for YData is the row's YValue
            % (1st and 5th values are left as NaN)
            obj.YDataForPlot(~wrap_idx,3) = obj.YData_I(~wrap_idx);
            
        end
    end
    
    methods
        %% Setters with custom logic
        function set.StartTimes(obj,val)
            obj.RecomputeData = true;
            obj.StartTimes = val;
        end
        function set.EndTimes(obj,val)
            obj.RecomputeData = true;
            obj.EndTimes = val;
        end
        function set.Colormap(obj,val)
            % Setter for Colormap will also change ColorMethod to colormapped
            obj.Colormap = val;
            obj.ColorMethod = 'colormapped';
        end
        function set.EventNames(obj,val)
            obj.UpdateDataTipLabels = true;
            obj.EventNames = val;
        end
        
        %% Setters & Getters for Dependent Properties
        function set.ColorData(obj,val)
            if ~isempty(val)
                obj.ColorDataMode = 'manual';
            else
                obj.ColorDataMode = 'auto';
            end
            obj.ColorData_I = val;
        end
        function val = get.ColorData(obj)
            if obj.ColorDataMode == "auto" && obj.RecomputeData
                updateChartData(obj);
            end
            val = obj.ColorData_I;
        end
        
        function set.YData(obj,val)
            obj.RecomputeData = true;
            if ~isempty(val)
                obj.YDataMode = 'manual';
            else
                obj.YDataMode = 'auto';
            end
            obj.YData_I = val;
        end
        function val = get.YData(obj)
            if obj.YDataMode == "auto" && obj.RecomputeData
                updateChartData(obj);
            end
            val = obj.YData_I;
        end
        
        function set.TimePeriod(obj,val)
            obj.RecomputeData = true;
            obj.TimePeriodMode = "manual";
            obj.TimePeriod_I = val;
        end
        function val = get.TimePeriod(obj)
            if obj.TimePeriodMode == "auto" && obj.RecomputeData
                updateChartData(obj);
            end
            val = obj.TimePeriod_I;
        end
        
        function set.XLimits(obj,val)
            obj.getAxes.XLim = val;
        end
        function val = get.XLimits(obj)
            val = obj.getAxes.XLim;
        end
        
        function set.YLimits(obj,val)
            obj.getAxes.YLim = val;
        end
        function val = get.YLimits(obj)
            val = obj.getAxes.YLim;
        end
        
        %% Convenience function support (title, etc.)
        function title(obj,txt)
            if isnumeric(txt)
                txt=num2str(txt);
            end
            obj.Title = txt;
        end
        
        function varargout = ylim(obj, varargin)
            % Call the standard ylim method on the axes,
            ax = obj.getAxes();
            [varargout{1:nargout}] = ylim(ax, varargin{:});
        end
        
        function varargout = xlim(obj, varargin)
            % Call the standard xlim method on the axes
            ax = obj.getAxes();
            [varargout{1:nargout}] = xlim(ax, varargin{:});
        end
        
        %% Chart State (used in Save/Load)
        function data = get.ChartState(obj)
            data = [];
            
            isLoadedStateAvailable = ~isempty(obj.ChartState);
            
            if isLoadedStateAvailable
                data = obj.ChartState;
            else
                % This block gets called when a .fig file is saved
                data = struct;
                ax = getAxes(obj);
                
                % Get axis limits only if mode is manual.
                if strcmp(ax.XLimMode,'manual')
                    data.XLimits = ax.XLim;
                end
                if strcmp(ax.YLimMode,'manual')
                    data.YLimits = ax.YLim;
                end
                
                % save values for the other dependent properties
                if obj.YDataMode == "manual"
                    data.YData = obj.YData_I;
                end
                if obj.ColorDataMode == "manual"
                    data.ColorData = obj.ColorData_I;
                end
                if obj.TimePeriodMode == "manual"
                    data.TimePeriod = obj.TimePeriod_I;
                end
            end
        end
        
        function loadstate(obj)
            % Call this method from setup to handle loading of .fig files
            data=obj.ChartState;
            ax = getAxes(obj);
            
            % Look for states that changed
            if isfield(data, 'XLimits')
                ax.XLim=data.XLimits;
            end
            if isfield(data, 'YLimits')
                ax.YLim=data.YLimits;
            end
            if isfield(data, 'YData')
                obj.YData=data.YData;
            end
            if isfield(data, 'ColorData')
                obj.ColorData=data.ColorData;
            end
            if isfield(data, 'TimePeriod')
                obj.TimePeriod=data.TimePeriod;
            end
        end
    end
end


% validator for the XLimits and YLimits properties
function mustBeLimits(a)
if numel(a) ~= 2 || a(2) <= a(1)
    throwAsCaller(MException('densityScatterChart:InvalidLimits', 'Specify limits as two increasing values.'))
end
end
