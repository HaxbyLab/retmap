function RET_localizer(subName, CurRun, listen)
%% RET LOCALIZER WITH WEDGE TEST
% PK: Feb. 23, 2010
% 96 TRs (2 sec) = 3 min, 12 secs
%% STARTUP COMMANDS
    close all;
    clear mex;
    IOPort('CloseAll');
    AssertOpenGL;  %Break if installed Psychtoolbox is not based on OpenGL or Screen() is not working properly.
    Screen('Preference','SkipSyncTests', 0); %skip hardware test
    %% GET SUBJECT INFORMATION
    if nargin < 1
      subName = input('Initials of subject? (default="tmp")  ','s');		% get subject's initials from user
    end
    if length(subName) < 1; subName = 'tmp'; end;
    if nargin < 2
      CurRun = str2double(input('Run Number? ','s'));
    end
    if nargin < 3
      listen = str2double(input('Listen for scanner [1=yes], 2=no? ','s'));
    end
    if isnan(listen); listen = 1; end;

    % name of data files to save relevant variables
    sequence = sprintf('%s%d_RET_WEDGEsequence.mat', subName, CurRun);
    buttons =  sprintf('%s%d_RET_WEDGEbuttons.mat',subName,CurRun);
    triggersfile =  sprintf('%s%d_RET_WEDGEtriggers.mat',subName,CurRun);
    listfile = sprintf('%s%d_RET_WEDGElist.mat',subName,CurRun);

%% DECLARE VARIABLES
    DEBUG_PRINTOUTS = 1;
    TotalPulseTime = [];
    TotalShowTime = [];
    data = [];
    buttonpress = [];
    triggers = [];
    presentations = cell(97,5);
    ang_list = [];
    RunOrder = zeros(97,2);
    repetitions = 5;  % number of circulations
    bigsize = 6;
    smallsize = 3;
    rectcolor = [0 255 0; 255 0 0; 0 0 255];
    %all the below related to checkerboard pattern
    rcycles = 8; % number of white/black circle pairs
    tcycles = 16; % number of white/black angular segment pairs (integer)
    flicker_freq = 4; % full cycle flicker frequency (Hz)
    flick_dur = 1/flicker_freq/2;
    flick = 1;
    num_flick = 1;
    TR = 2.;
    ScreenNum = max(Screen('Screens'));

%% MAKE PRESENTATIONS LISTS
    ang = (360/tcycles):(360/tcycles):360;
    for z=1:repetitions
        ang_list = [ang_list, ang];
    end

    if mod(CurRun,2)~=0; % odd run, wedge counterclockwise
        temp = ang_list(1:length(ang_list));
    else % even run, wedge clockwise
        temp = ang_list(length(ang_list):-1:1);
    end

    RunOrder(9:length(ang_list)+8,1) = temp;

    steps = [-1, 0];

    while length(find(RunOrder(:,2)~=0)) < 48
        for z = 1:length(RunOrder);
            if mod(z,2) == 0;
                tempstep = steps(randperm(2)); % pick a random step
                RunOrder(z+tempstep(1),2) = round(rand)+1; % make that position 1 or 2
                if tempstep(1) ~= 0; RunOrder(z,2) = 0; end;
            else
                RunOrder(z,2) = 0;
            end
        end
    end


%% SUBJECT PROMPT
    HideCursor; %hides the cursor
    [w,rect]=Screen('OpenWindow',ScreenNum,[127 127 127], [], [], [], [], kPsychNeedFastOffscreenWindows); %kPsychNeedFastBackingStore
    Priority(2); %sets the priority to the maximum possible
    x0 = rect(3)/2; % screen center
    y0 = rect(4)/2;
    prompt = imread('RETprompt.png');
    [ysize,xsize,ncolors]=size(prompt);
    xsize = (rect(3)/6)*(xsize/ysize);
    ysize = rect(3)/6;
    t=Screen('MakeTexture',w,prompt); %converting image matrix to a texture
    destrect = [x0-xsize, y0-ysize, x0+xsize, y0+ysize];
    Screen('DrawTexture',w,t,[],destrect);
    Screen('Flip',w, [], 1);
    if listen ~= 1
        WaitSecs(1); %% ONLY FOR DEBUGGING
    else
    end

%% MAKE CHECKERBOARDS
    hi_index=255; % black color
    lo_index=0; % white color
    bg_index =128; %background
    xysize = sqrt(power(rect(3),2)+power(rect(4),2)); % wedge diameter
    s = xysize/sqrt(2); % size used for mask
    xylim = 2*pi*rcycles;
    [x,y] = meshgrid(-xylim:2*xylim/(xysize-1):xylim, -xylim:2*xylim/(xysize-1):xylim);
    at = atan2(y,x);
    checks = ((1+sign(sin(at*tcycles)+eps) .* ...
    sign(sin(sqrt(x.^2+y.^2))))/2) * (hi_index-lo_index) + lo_index;
    circle = x.^2 + y.^2 <= xylim^2;
    checks = circle .* checks + bg_index * ~circle;
    t(1) = Screen('MakeTexture', w, checks);
    t(2) = Screen('MakeTexture', w, hi_index - checks); % reversed contrast
%% PRE-PRESENTATION
    if listen == 1
        IOPort('Verbosity', 10);
        [P4, openerror] = IOPort('OpenSerialPort', '/dev/ttyUSB0','BaudRate=115200'); %opens port for receiving scanner pulse
        IOPort('Flush', P4); %flush event buffer
    end
    DynScan = 1;
    temp_data = 1;
    bigrect = [x0-bigsize, y0-bigsize, x0+bigsize,y0+bigsize];
    smallrect = [x0-smallsize, y0-smallsize, x0+smallsize,y0+smallsize];

    %% Visualize that we are ready now
    Screen('TextFont', w, 'Arial');
    Screen('TextStyle', w, 0);
    Screen('DrawText', w, 'Waiting for scanner', 400, 520, 80);
    Screen('Flip', w, [], 2, 1);
    sprintf('Ready to present subject %s run %d. listen:%d\n', subName, CurRun, listen)

% %% IMAGE PRESENTATION
    NRuns = length(RunOrder)-1
    while DynScan <= NRuns
        if listen == 1;
            tprev = GetSecs;
            pulse = [];
            while isempty(pulse)
                [pulse,temptime,readerror] = IOPort('read',P4,0,1);
            end
            if length(triggers) == 0; t0 = temptime; end;
            if DEBUG_PRINTOUTS;
                tnow = GetSecs;
                navail = IOPort('BytesAvailable', P4);
                fprintf('%3d Got %c at %.5f. / %.5f waited %.5f avail: %d',
                        DynScan, pulse, temptime, tnow, tnow - tprev, navail);
                if length(triggers)>0;
                    fprintf(' dt=%.5f', temptime-triggers(end));
                    if pulse == 53; fprintf(' delay=%.5f', tnow-t0-(DynScan-1)*TR); end;
                end
                fprintf('\n');
            end;
        else
            pulse = 53;
            temptime = GetSecs;
        end
        if pulse == 'q'; break; end; % quit if 'q'
        if pulse == 53; %if a pulse has been received from the scanner
            triggers = [ triggers; temptime ];
            if RunOrder(DynScan,1) == 0; % THIS IS FOR THE BLANK
                Screen('FillRect',w,[127 127 127]); %fills the whole screen - changes background color%
                Screen('FillRect',w,rectcolor(RunOrder(DynScan,2)+1,:),bigrect);
                Screen('FillRect',w,[255 255 0],smallrect);
                Screen('Flip', w);
                ShowTime = GetSecs;
                WaitSecs(.240); %after 240 ms
                Screen('FillRect',w,rectcolor(1,:),bigrect);
                Screen('FillRect',w,[255 255 0],smallrect);
                Screen('Flip', w);
                presentations(DynScan,:)= {CurRun,DynScan,RunOrder(DynScan,1),RunOrder(DynScan,2),ShowTime};
                if listen ~= 1 || DynScan == NRuns % So if is the last trial
                    WaitSecs(1.75); % ONLY FOR DEBUGGING - TO MIMIC SCANNER BEHAVIOR
                end
                DynScan = DynScan + 1;
            else  % PRESENT IMAGE

                while num_flick <=(TR/flick_dur) % 2 seconds of flicker
                    Screen('DrawTexture', w, t(flick));
                    theta1 = deg2rad(RunOrder(DynScan,1));
                    theta2 = deg2rad((180-(360/tcycles)+RunOrder(DynScan,1))); %offset
                    st1 = sin(theta1); ct1 = cos(theta1);
                    st2 = sin(theta2); ct2 = cos(theta2);
                    xy1 = s * [0,0; -st1,-ct1; -st1-ct1,st1-ct1; st1-ct1,st1+ct1; -st2,-ct2] + ones(5,1) * [x0 y0];
                    xy2 = s * [0,0; st1,ct1; -st2-ct2,st2-ct2; st2-ct2,st2+ct2; st2,ct2] + ones(5,1) * [x0 y0];
                    Screen('FillPoly', w, bg_index, xy1);
                    Screen('FillPoly', w, bg_index, xy2);
                    Screen('FillRect',w,rectcolor(RunOrder(DynScan,2)+1,:),bigrect);
                    Screen('FillRect',w,[255 255 0],smallrect);
                    if num_flick == 1; ShowTime = GetSecs;
                    elseif num_flick > 3; % after 240 ms
                             Screen('FillRect',w,rectcolor(1,:),bigrect);
                             Screen('FillRect',w,[255 255 0],smallrect);
                    end
                    Screen('Flip', w, [], 0, 0); %usually 2 , 1 for do not sync
                    tnow = GetSecs;
                    sleep_dur = temptime + num_flick*flick_dur - tnow;
                    flick = 3-flick;
                    if num_flick < (TR/flick_dur)
					   % Skip waiting on the last one -- just wait on the trigger above
                       WaitSecs(sleep_dur); % 8 hz flicker
                    end
                    num_flick = num_flick + 1;
                end
                presentations(DynScan,:)= {CurRun,DynScan,RunOrder(DynScan,1),RunOrder(DynScan,2),ShowTime};
                DynScan = DynScan + 1;
                num_flick = 1;
            end
            TotalShowTime = [TotalShowTime; ShowTime];
            ShowTime = [];
            pulse = [];
        else
            if ~isempty(pulse); buttonpress = [buttonpress; pulse, temptime]; end% add to buttonpresses
                pulse = [];
        end
    end

    tend = GetSecs;
    %% CLOSING COMMANDS
    cd './data';
    save(sequence,'presentations'); %saves the sequence data
    save(buttons, 'buttonpress'); %saves the buttonpresses
    save(triggersfile,'triggers'); %saves the list

    Screen('CloseAll');
    IOPort('CloseAll');
    cd ..

    dt = triggers(2:end)-triggers(1:end-1) - 2;
    fprintf('Post-analysis of triggers delays. Total runtime=%.3f Min=%.3f Max=%.3f\n',
    		tend-t0, min(dt), max(dt));
end
