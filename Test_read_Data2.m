clear 'all'
close 'all'
%-------------------------------------------------------------------------------------------
%set global fstart
%global fstart
%-------------------------------------------------------------------------------------------
setFMCWParams;
%-------------------------------------------------------------------------------------------
CBstaticRemoval = false;

numFilesInSeries = [20, 30, 5, 10, 15];

backGroundIndex = 3;

%which figures to show:
%SumAndDelayBeamformer/MUSIC/rangeDoppCube/bmp/undistorted_bmp
showFigures = [1,1,1,1,1];

subBackground = 1;

testReadDataResult = struct;
%--------------------------------------------------------------------------------------------

path = 'C:\Users\odysseas\Desktop\Image Sets\series';

%first read background data
series = backGroundIndex;

rangeDoppCubeBkgr = zeros(numFilesInSeries(series), numChirps,numTX*numRX,numSamp);

for files=1:numFilesInSeries(series)
    fileNameRadar = sprintf('%s%02d\\radar%02d.mat', path, series, files);
    load(fileNameRadar);

    fileNameImage = sprintf('%s%02d\\image%02d.bmp', path, series, files);
    image = imread(fileNameImage);        

    matRX = rawDataAllFrames;
    
    matMIMOBkgr = zeros(numChirps,numTX*numRX,numSamp);

    von = 1;
    bis = numSamp;
    for ii = 1:numChirps
        for jj = 1:numTX
            matMIMOBkgr(ii,(jj-1)*4+1:(jj*4),:) = matRX(:,von:bis);
            von = von + numSamp;
            bis = bis + numSamp;
        end
    end
    
    rangeDoppCube = RangeDopplerCalc(matMIMOBkgr,'hamming'); 
    rangeDoppCubeBkgr(files,:,:,:) = rangeDoppCube;
end 
    


for series=5:5
    if series ~= backGroundIndex
        for files=1:numFilesInSeries(series)        
            fileNameRadar = sprintf('%s%02d\\radar%02d.mat', path, series, files);
            load(fileNameRadar);

            fileNameImage = sprintf('%s%02d\\image%02d.bmp', path, series, files);
            image = imread(fileNameImage);        

            matRX = rawDataAllFrames;

            matMIMO = zeros(numChirps,numTX*numRX,numSamp);

            von = 1;
            bis = numSamp;
            for ii = 1:numChirps
                for jj = 1:numTX
                    matMIMO(ii,(jj-1)*4+1:(jj*4),:) = matRX(:,von:bis);
                    von = von + numSamp;
                    bis = bis + numSamp;
                end
            end

            %-------------------------------------------------------------------------------------------
            % ggf. Static Clutter Removal
            if CBstaticRemoval

                for ii =1:12
                    for cc = 1:32
                        matMIMO(cc,ii,:) = squeeze(matMIMO(cc,ii,:)) - mean(squeeze(matMIMO(cc,ii,:)));
                    end
                    for rr = 1:273
                        matMIMO(:,ii,rr) = squeeze(matMIMO(:,ii,rr)) - mean(squeeze(matMIMO(:,ii,rr)));
                    end
                end
            end
            %--------------------------------------------------------------------------------------------
            % Range Doppler Calculation
            rangeDoppCube = RangeDopplerCalc(matMIMO,'hamming');            
            %--------------------------------------------------------------------------------------------
            if showFigures(1) == 1
                figure(1);
                theta = -90:90;
                SaD = zeros(numChirps,numSamp,size(theta,2));
                SaDBkgr = zeros(numChirps,numSamp,size(theta,2));
                for cc = 1:numChirps
                    [ang,ran,SaD(cc,:,:)] = SumAndDelayBeamformer(squeeze(matMIMO(cc,1:8,:)),theta,fstart,BW,dAnt);
                    [~,~,SaDBkgr(cc,:,:)] = SumAndDelayBeamformer(squeeze(matMIMOBkgr(cc,1:8,:)),theta,fstart,BW,dAnt); 
                end
                meanSaD = squeeze(mean(SaD,1));
                meanSaD = mag2db(abs(meanSaD));
                
                if subBackground == 1
                    meanSaDBkgr = squeeze(mean(SaDBkgr,1));
                    meanSaDBkgr = mag2db(abs(meanSaDBkgr));
                    meanSaD = meanSaD-meanSaDBkgr;
                end
                
                meanSaD = meanSaD-max(meanSaD,[],'all');

                Rmat = repmat(ran, length(ang),1);
                Amat = repmat(ang', 1, length(ran));
                X = cosd(Amat).*Rmat;
                Y = sind(Amat).*Rmat;
                pcolor(Y,X,meanSaD.')
                shading("interp")
                view([0 0 1])
                ylabel('Range (m)')
                xlabel('Cross Range (m)')
                colorbar()
                ylim([min(ran) max(ran)])
                xlim([-max(ran) max(ran)])   
                
                %save first numMax maxima
                %---------------------------------------
                numMax = 3;
                sizeFilter = [2,10];%must be even!!

                meanSaDCur = imfilter(meanSaD, ones(sizeFilter)/(sizeFilter(1)*sizeFilter(2)),'symmetric');
                [numRows, numCols] = size(meanSaDCur);

                testReadDataResult(files).maxDist = [];
                testReadDataResult(files).maxAngl = [];
                for i1 = 1:numMax
                    [maxVal, maxInd] = max(meanSaDCur(:));

                    maxCol = floor(1+(maxInd-1)/numRows);
                    maxRow = 1+mod((maxInd-1),numRows);

                    testReadDataResult(files).maxDist = [testReadDataResult(files).maxDist, ran(maxRow)];
                    testReadDataResult(files).maxAngl = [testReadDataResult(files).maxAngl, ang(maxCol)];

                    meanSaDCur(max(maxRow-sizeFilter(1),1):min(numRows, maxRow+sizeFilter(1)),...
                               max(maxCol-sizeFilter(2),1):min(numCols, maxCol+sizeFilter(2))) = min(meanSaDCur(:));
                end
            end
            %-------------------------------------------------------------------------------------
            if showFigures(2) == 1
                figure(2);
                rangeDoppVirULA = squeeze(rangeDoppCube(:,1:8,:));
                theta = 40:0.1:140;
                [musSpk,~] = MUSICdoa(rangeDoppVirULA,theta,eye(8),'pseudo','MDL');
                [MaxMusic,idxMusic] = max(musSpk);
                testReadDataResult(files).maxTheta = theta(idxMusic);
                plot(theta,musSpk);
                hold on
                plot (theta(idxMusic),MaxMusic,'bo');
                grid("on")
                xlabel('Angle ({\circ})')
                ylabel('P_{MUSIC}(dB)')
                xlim([40 140])
                ylim([floor(min(musSpk)/5)*5, ceil(max(musSpk)/5)*5])
            end
            %--------------------------------------------------------------------------------------
            if showFigures(3) == 1
                figure(3);  
                imshow(image);
                title('Original Image')
            end
            %---------------------------------------------------------------------------------------
%             [translationVector,normedTranslationVector,undistortedImage,imagePoints] = ChessBoardDistance(image);
%             testReadDataResult(files).cameraDistance = normedTranslationVector/1000; 
%             testReadDataResult(files).translationVector = translationVector/1000; 
% 
%             if showFigures(4) == 1
%                 figure(4);  
%                 imshow(undistortedImage);
%                 title('Undistorted Image')
%                 hold on
%                 plot(imagePoints(:,1),imagePoints(:,2),'ro');
%             end
            %---------------------------------------------------------------------------------------

            if showFigures(5) == 1
                figure(5)
                [Rmesh,Vmesh] = meshgrid(rvek,vvek);
                plotData = squeeze( (sum(abs(rangeDoppCube), 2)/size(rangeDoppCube,2)));
                plotData = mag2db(plotData);
                if subBackground == 1
                   %average over antennas 
                    bkgr = squeeze( (sum(abs(rangeDoppCubeBkgr), 3)/size(rangeDoppCubeBkgr,3))); 
                    bkgr = squeeze( (sum(bkgr, 1)/size(bkgr,1))); 
                    bkgr = mag2db(bkgr);
                else
                    bkgr = zeros(size(plotData));
                end
                  surf(Vmesh, Rmesh, plotData-bkgr);
                   ylim([min(rvek), max(rvek)]);
                   xlim([min(vvek), max(vvek)]);
                   zlim([floor(min(plotData,[],'all')/5)*5, ceil(max(plotData,[],'all')/5)*5]);
                   caxis([floor(min(plotData,[],'all')/5)*5, ceil(max(plotData,[],'all')/5)*5]);
                   colorbar()
                   ylabel('Distance (meters)')
                   xlabel('Velocity (meters/second)')
                   zlabel('Signal Strength (dB)')
                  
                   noNoisePlotData = plotData-bkgr;
                   [noNoisePlotData,idxNoNoise] = max(noNoisePlotData(:));
                   testReadDataResult(files).radarMax = noNoisePlotData;
                   testReadDataResult(files).radarMaxDist = Rmesh(idxNoNoise);
                   testReadDataResult(files).radarMaxSpeed = Vmesh(idxNoNoise);
            end

            %-------------------------------------------------------------------------------------------
            pause(0.1);
        end
        measurementsData = strcat('testReadDataResult',num2str(series),'.mat');
        save (measurementsData,'testReadDataResult');
    end
end
