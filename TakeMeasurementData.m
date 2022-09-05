clear 'all'
close 'all'

%%
setFMCWParams;
numChirpsProFrame = numTX*numChirps;

%%
%here you can choose a different webcam index
WebcamIndex = 1;
%choose the folder name you want to save the images in
SaveFolder = './images';

mkdir(SaveFolder);

SaveCounter = 1;

camList = webcamlist;

if isempty(camList) 
   disp('you require at least one webcams');
   disp('hit a key to exit');
   pause();
   exit();
end


if 1 < length(camList)
   disp('you have several webcams available:');
   for i0 = 1:length(camList)
       disp(strcat('WebcamIndex: ', num2str(i0)));
       disp(camList(i0));
   end
   disp(strcat('currently the index ', num2str(WebcamIndex), ' is chosen. Change if you want to use a different camera.'));   
   pause();
end

cam = webcam(char(camList(WebcamIndex)));

disp('available resolutions for chosen camera:');
for i0 = 1:length(cam.AvailableResolutions)
    disp(cam.AvailableResolutions(i0));
end


cam.Resolution = '1920x1080';
disp('chosen resolution is: ');
disp(strcat('camera:  ', cam.Resolution));

%grab an image
img = snapshot(cam);

figure(1);
imshow(img);

disp('adjust the camera position and then hit s-key to save an image; hit e-key to stop');

k=[];
set(gcf,'keypress','k=get(gcf,''currentchar'');');

while 1
  img = snapshot(cam);
  
  figure(1);
  imshow(img);title(strcat('Index: ', num2str(SaveCounter)));
     
  pause(0.1)

  if ~isempty(k)
    if strcmp(k,'e');        
        clear('cam');
        break; 
    end;
    if strcmp(k,'p'); 
        pause; k=[]; 
    end;
    if strcmp(k,'s'); 
        imwrite(img, sprintf('./%s/image%02d.bmp',SaveFolder,SaveCounter));   
        [messdaten,rawDataAllFrames,numByteProSamp] = AcquireRadarData(1);
        save(sprintf('./%s/radar%02d.mat',SaveFolder,SaveCounter),'rawDataAllFrames','numByteProSamp','numChirps','numChirpsProFrame','numRX','numTX','numSamp'); 
        SaveCounter = SaveCounter+1;
        k=[];
    end;
  end
end

 %%
 %%