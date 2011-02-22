%% RET LOCALIZER WITH WEDGE TEST
% PK: Feb. 23, 2010
% 96 TRs (2 sec) = 3 min, 12 secs
%% STARTUP COMMANDS
    close all;
    clear all;
    clear mex;
    IOPort('Closeall');
    AssertOpenGL;  %Break if installed Psychtoolbox is not based on OpenGL or Screen() is not working properly.
    Screen('Preference','SkipSyncTests',1); %skip hardware test
%% GET SUBJECT INFORMATION
    subName = input('Initials of subject? (default="tmp")  ','s');		% get subject's initials from user
    if length(subName) < 1; subName = 'tmp'; end;

    CurRun = str2double(input('Run Number? ','s'));		
    
    listen = str2double(input('Listen for scanner [1=yes], 2=no? ','s'));
    if isnan(listen); listen = 1; end;

    sequence = sprintf('%s%d_RET_WEDGEsequence.mat',subName,CurRun);	% name of data file to save relevant variables
    buttons =  sprintf('%s%d_RET_WEDGEbuttons.mat',subName,CurRun);
    triggersfile =  sprintf('%s%d_RET_WEDGEtriggers.mat',subName,CurRun);
    listfile = sprintf('%s%d_RET_WEDGElist.mat',subName,CurRun);

%% DECLARE VARIABLES
    TotalPulseTime =[];
    TotalShowTime =[];
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
                if tempstep(1) ~= 0; RunOrder(z,2) = 0; else end;
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
    Screen('Flip',w);
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
        [P4, openerror] = IOPort('OpenSerialPort', '/dev/ttyUSB0','BaudRate=115200'); %opens port for receiving scanner pulse
        IOPort('Flush', P4); %flush event buffer
    else
    end
    DynScan = 1;
    temp_data=1;
    bigrect = [x0-bigsize, y0-bigsize, x0+bigsize,y0+bigsize];
    smallrect = [x0-smallsize, y0-smallsize, x0+smallsize,y0+smallsize];
    disp 'Getting to presentation loop';
    disp 'Listen ', listen;

% %% IMAGE PRESENTATION
    while DynScan<=(length(RunOrder)-1)
        if listen == 1;
            [pulse,temptime,readerror] = IOPort('read',P4,1,1);
            if isempty(pulse); continue; end;
            printf("Got %c at %.2f\n", pulse, temptime)
        else 
            pulse = 53;
        end 
        if pulse == 53; %if a pulse has been received from the scanner
            triggers = [ triggers; temptime ];
            if RunOrder(DynScan,1) == 0; % THIS IS FOR THE BLANK
                Screen('FillRect',w,[127 127 127]); %fills the whole screen - changes background color%
                Screen('FillRect',w,rectcolor(RunOrder(DynScan,2)+1,:),bigrect);
                Screen('FillRect',w,[255 255 0],smallrect);
                Screen('Flip',w);
                ShowTime = GetSecs;
                WaitSecs(.240); %after 240 ms
                Screen('FillRect',w,rectcolor(1,:),bigrect);
                Screen('FillRect',w,[255 255 0],smallrect);
                Screen('Flip',w,[],2);
                presentations(DynScan,:)= {CurRun,DynScan,RunOrder(DynScan,1),RunOrder(DynScan,2),ShowTime}; 
                if listen ~= 1
                    WaitSecs(1.75); % ONLY FOR DEBUGGING - TO MIMIC SCANNER BEHAVIOR
                    else
                end
                DynScan = DynScan + 1;
            else  % PRESENT IMAGE
                while num_flick <=(2/flick_dur)-1 % 2 seconds of flicker 
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
                    Screen('Flip',w,[],2); %usually 2
                    WaitSecs(flick_dur); % 8 hz flicker
                    flick = 3-flick;
                    presentations(DynScan,:)= {CurRun,DynScan,RunOrder(DynScan,1),RunOrder(DynScan,2),ShowTime}; 
                    num_flick = num_flick + 1;
                end
                DynScan = DynScan + 1;
                num_flick = 1;
            end
            TotalShowTime = [TotalShowTime; ShowTime];
            ShowTime = [];
            pulse = [];
        else
            if ~isempty(pulse); buttonpress = [buttonpress; pulse, temptime]; else end% add to buttonpresses
                pulse = [];
        end
    end
     
%% CLOSING COMMANDS
cd './data';
save(sequence,'presentations'); %saves the sequence data
save(buttons, 'buttonpress'); %saves the buttonpresses
save(triggersfile,'triggers'); %saves the list

Screen('CloseAll');
IOPort('Closeall');
cd ..
