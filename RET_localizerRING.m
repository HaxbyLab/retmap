%% RET LOCALIZER WITH RINGS
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
    if listen == '' || isnan(listen); listen = 1; end;

    sequence = sprintf('%s%d_RET_RINGsequence.mat',subName,CurRun); % name of data file to save relevant variables
    buttons =  sprintf('%s%d_RET_RINGbuttons.mat',subName,CurRun);
    triggersfile = sprintf('%s%d_RET_RINGtriggers.mat',subName,CurRun);
    listfile = sprintf('%s%d_RET_RINGlist.mat',subName,CurRun);

%% DECLARE VARIABLES
    TotalPulseTime =[];
    TotalShowTime =[];
    data = [];
    buttonpress = [];
    triggers = [];
    presentations = cell(97,5);
    ring_list = [];
    RunOrder = zeros(97,2);
    repetitions = 5;  % number of repetitions in a run
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
     
    
%% MAKE CHECKERBOARDS
    HideCursor; %hides the cursor
    [w,rect]=Screen('OpenWindow',ScreenNum,[127 127 127], [], [], [], [], kPsychNeedFastOffscreenWindows); %kPsychNeedFastBackingStore
    Screen(w,'BlendFunction',GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    Priority(2); %sets the priority to the maximum possible
    hi_index=255; % black color
    lo_index=0; % white color
    bg_index =128; %background
    xysize = sqrt(power(rect(3),2)+power(rect(4),2)); % wedge diameter
    s = xysize/sqrt(2); % size used for mask
    xylim = 2*pi*rcycles;
    [x,y] = meshgrid(-xylim:2*xylim/(xysize-1):xylim, -xylim:2*xylim/(xysize-1):xylim);
    at = atan2(y,x);
    checks = ((1+sign(sin(at*tcycles)+eps) .* sign(sin(sqrt(x.^2+y.^2))))/2) * (hi_index-lo_index) + lo_index;
    circle = x.^2 + y.^2 <= xylim^2;
    checks = circle .* checks + bg_index * ~circle;
    t(1) = Screen('MakeTexture', w, checks);
    t(2) = Screen('MakeTexture', w, hi_index - checks); % reversed contrast
    circlemask = ones(xysize,xysize,4);
    circlemask(:,:,1:3)=128;
%% MAKE PRESENTATION LISTS
    sizes = 0:(xylim/16):xylim-(xylim/16);
    for s = 1:length(sizes)
        smallcircle = x.^2 + y.^2 <= (sizes(s)^2);
        smallcircle = smallcircle*255;
        if s == length(sizes)
            maskcircle = x.^2 + y.^2 <= 100000;
        else
            maskcircle = x.^2 + y.^2 <= (sizes(s+1)^2);
        end
        maskcircle = ~maskcircle*255;
        circlemask(:,:,4) = smallcircle+maskcircle;
        masktextures(s)=Screen('MakeTexture', w, circlemask);
    end

    for z=1:repetitions
        ring_list = [ring_list, masktextures];
    end

    if mod(CurRun,2)~=0; % odd run, ring expanding
        temp = ring_list(1:length(ring_list));
    else % even run, ring contracting
        temp = ring_list(length(ring_list):-1:1);
    end

    RunOrder(9:length(ring_list)+8,1) = temp;

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
    x0 = rect(3)/2; % screen center
    y0 = rect(4)/2;
    prompt = imread('RETprompt.png');
    [ysize,xsize,ncolors]=size(prompt);
    xsize = (rect(3)/6)*(xsize/ysize);
    ysize = rect(3)/6;
    prompt_texture=Screen('MakeTexture',w,prompt); %converting image matrix to a texture
    destrect = [x0-xsize, y0-ysize, x0+xsize, y0+ysize];
    Screen('DrawTexture',w,prompt_texture,[],destrect);
    Screen('Flip',w);
    if listen ~= 1
        WaitSecs(1); %% ONLY FOR DEBUGGING
    else
    end
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
%% IMAGE PRESENTATION
    while DynScan<=(length(RunOrder)-1)
        if listen == 1;
            [pulse,temptime,readerror] = IOPort('read',P4,1,1);
            if isempty(pulse); continue; end;
            printf('Got %c at %.2f\n', pulse, temptime)
        else 
            pulse = 53;
            temptime = GetSecs;
        end 
        if pulse == 53; %if a pulse has been received from the scanner
            triggers = [triggers; temptime];
            if RunOrder(DynScan,1) == 0; % THIS IS FOR THE BLANK
                Screen('FillRect',w,[127 127 127]); %fills the whole screen - changes background color%
                Screen('FillRect',w,rectcolor(RunOrder(DynScan,2)+1,:),bigrect);
                Screen('FillRect',w,[255 255 0],smallrect);
                Screen('Flip',w);
                ShowTime = GetSecs;
                WaitSecs(.24); %after 240 ms
                Screen('FillRect',w,rectcolor(1,:),bigrect);
                Screen('FillRect',w,[255 255 0],smallrect);
                Screen('Flip',w);
                presentations(DynScan,:)= {CurRun,DynScan,RunOrder(DynScan,1),RunOrder(DynScan,2),ShowTime}; 
                if listen ~= 1
                    WaitSecs(1.75); % ONLY FOR DEBUGGING - TO MIMIC SCANNER BEHAVIOR
                    else
                end
                DynScan = DynScan + 1;
            else  % PRESENT IMAGE
                while num_flick <=(2/flick_dur)-1 % 2 seconds of flicker 
                    Screen('DrawTexture', w, t(flick)); 
                    Screen('DrawTexture', w, RunOrder(DynScan,1));                   
                    Screen('FillRect',w,rectcolor(RunOrder(DynScan,2)+1,:),bigrect);
                    Screen('FillRect',w,[255 255 0],smallrect);
                    if num_flick == 1; ShowTime = GetSecs; 
                    elseif num_flick > 3; % after 240 ms
                             Screen('FillRect',w,rectcolor(1,:),bigrect);
                             Screen('FillRect',w,[255 255 0],smallrect);
                    end
                    Screen('Flip',w,[],2);
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
    save(listfile,'RunOrder'); %saves the list
    save(triggersfile,'triggers'); %saves the list


    Screen('CloseAll');
    IOPort('Closeall');
    cd ..
