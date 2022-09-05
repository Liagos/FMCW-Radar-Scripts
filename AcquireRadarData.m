function [messdaten,rawDataAllFrames,numByteProSamp] = AcquireRadarData(numFramesToRecord)
setFMCWParams;

ShowFrame = 1;
CBstaticRemoval = false;
CBjavaUDP = true;


rawDataAllFrames = [];
messdaten = [];
numByteProSamp = 4;

CONFIG_FPGA_GEN_CMD_CODE = ['5a'; 'a5'; '03'; '00'; '06'; '00'; '01'; '02'; '01'; '02'; '03'; '1e'; 'aa'; 'ee'];
CONFIG_FPGA_GEN_CMD_RESP = ['5a'; 'a5'; '03'; '00'; '00'; '00'; 'aa'; 'ee'];
CONFIG_PACKET_DATA_CMD_CODE = ['5a'; 'a5'; '0b'; '00'; '06'; '00'; 'be'; '05'; '35'; '0c'; '00'; '00'; 'aa'; 'ee'];
CONFIG_PACKET_DATA_CMD_RESP = ['5a'; 'a5'; '0b'; '00'; '00'; '00'; 'aa'; 'ee'];
READ_FPGA_VERSION_CMD_CODE = ['5a'; 'a5'; '0e'; '00'; '00'; '00'; 'aa'; 'ee'];
READ_FPGA_VERSION_CMD_RESP =['5a'; 'a5'; '0e'; '00'; '02'; '04'; 'aa'; 'ee'];
RECORD_START_CMD_CODE = ['5a'; 'a5'; '05'; '00'; '00'; '00'; 'aa'; 'ee'];
RECORD_START_CMD_RESP =  ['5a'; 'a5'; '05'; '00'; '00'; '00'; 'aa'; 'ee'];
RECORD_STOP_CMD_CODE = ['5a'; 'a5'; '06'; '00'; '00'; '00'; 'aa'; 'ee'];
RECORD_STOP_CMD_RESP = ['5a'; 'a5'; '06'; '00'; '00'; '00'; 'aa'; 'ee'];

%% Vorbereitungen fuer LVDS
numChirpsProFrame = numTX*numChirps;
numBytesProFrame = numSamp*numByteProSamp*numRX*numChirpsProFrame;
numMaxByteProDatagram = 1456;
sizeStreamHeader = 10;
sizeDatagram = numMaxByteProDatagram+sizeStreamHeader;

if mod(numBytesProFrame,numMaxByteProDatagram) ~=0
    error('Keine Ganze Anzahl an vollen UDP Datagrammen. ie wird nicht unterstuetzt. Code anpassen!');
    return
else
    numDatagramsProFrame = numBytesProFrame/numMaxByteProDatagram;
end


%%
%Preparation for UDP/Serial Communication
IPDCA1000str = '192.168.33.180';
cmdPortStr =  ['COM' '3'];

udpConfigObj = udp(IPDCA1000str,4096,'OutputBufferSize',1024,'InputBufferSize',1024);
udpReadConfigObj = udp(IPDCA1000str,1024,'LocalPort',4096,'OutputBufferSize',1024);

try
    fopen(udpReadConfigObj);
    fopen(udpConfigObj);
catch
    fclose(udpConfigObj);
    fclose(udpReadConfigObj);
    error('Cannot open UDP objects for DCA1000, IP adress correct?');
    err = 1;
    return
    
end

try
    serObj = serialport(cmdPortStr,115200,'DataBits',8,'StopBits',1,'Parity','none');
    configureTerminator(serObj,"LF");
catch
    error = ('Cannot open serial Port to IWR6843, COM Port Correct?');
    err = 1;
    return
end
%%
% Configuration of DCA1000EVM
try
    udpCMD = hex2dec(CONFIG_FPGA_GEN_CMD_CODE);
    fwrite(udpConfigObj,udpCMD,'uint8');
    response = fread(udpReadConfigObj,8,'uint8');
    
    if response ~= hex2dec(CONFIG_FPGA_GEN_CMD_RESP)
        fclose(udpConfigObj);
        fclose(udpReadConfigObj);
        error('Connecting to DCA1000 fail');
        err = 1;
        return
    end
catch
    fclose(udpConfigObj);
    fclose(udpReadConfigObj);
    err = 1;
    error('Connecting to DCA1000 fail');
    return
end


%%
%Ethernet Packet Delay
try
    udpCMD = hex2dec(CONFIG_PACKET_DATA_CMD_CODE);
    fwrite(udpConfigObj,udpCMD,'uint8');
    response = fread(udpReadConfigObj,8,'uint8');
    
    if response ~= hex2dec(CONFIG_PACKET_DATA_CMD_RESP)
        fclose(udpConfigObj);
        fclose(udpReadConfigObj);
        error('Cannot set packetlength of DCA1000');
        err = 1;
        return
    end
catch
    fclose(udpConfigObj);
    fclose(udpReadConfigObj);
    error('Cannot set packetlength of DCA1000');
    err = 1;
    return
end


%%
%Read Version of DCA1000EVM
try
    udpCMD = hex2dec(READ_FPGA_VERSION_CMD_CODE);
    fwrite(udpConfigObj,udpCMD,'uint8');
    response = fread(udpReadConfigObj,8,'uint8');
    
    if response ~= hex2dec(READ_FPGA_VERSION_CMD_RESP)
        fclose(udpConfigObj);
        fclose(udpReadConfigObj);
        error('DCA1000 error: Unexpected Version answer');
        err = 1;
        return
    end
catch
    udpCMD = hex2dec(READ_FPGA_VERSION_CMD_CODE);
    fwrite(udpConfigObj,udpCMD,'uint8');
    response = fread(udpReadConfigObj,8,'uint8');
    
    if response ~= hex2dec(READ_FPGA_VERSION_CMD_RESP)
        fclose(udpConfigObj);
        fclose(udpReadConfigObj);
        error('DCA1000 error: Unexpected Version answer');
        err = 1;
        return
    end
end


%%
%DCA Init fertig
numFrames = numFramesToRecord;

while numFrames >= 1
    numFrames = numFrames - 1;
    %%
    %Trigger DCA1000EVM
    tic
    try
        udpCMD = hex2dec(RECORD_START_CMD_CODE);
        fwrite(udpConfigObj,udpCMD,'uint8');
        response = fread(udpReadConfigObj,8,'uint8');
        
        if response ~= hex2dec(RECORD_START_CMD_RESP)
            fclose(udpConfigObj);
            fclose(udpReadConfigObj);
            error('DCA1000 error: Start Record failed');
            err = 1;
            return
        end
    catch
        fclose(udpConfigObj);
        fclose(udpReadConfigObj);
        error('DCA1000 error: Start Record failed');
        err = 1;
        return
    end
    
    %% Record Data
    if CBjavaUDP
        % Java version ist super schnell
        try
            rawDataWithHeader = MatlabMulticastCapture(numDatagramsProFrame,sizeDatagram,IPDCA1000str,4098,serObj,"StartFrame");
        catch
            fclose(udpConfigObj);
            fclose(udpReadConfigObj);
            error('Data transfer with Java UDP failed,(Timeout???)');
            err = 1;
            return
        end
    else
        try
            rawDataWithHeader = zeros(numDatagramsProFrame,sizeDatagram,'uint8');
            udpReadDataObj = udp(IPDCA1000str,1024,'LocalPort',4098,'InputBufferSize',512*1024,'DatagramTerminateMode','off');
            fopen(udpReadDataObj);
            writeline(serObj,"StartFrame");
            for ii = 1:numDatagramsProFrame
                tmp = fread(udpReadDataObj,sizeDatagram,'uint8');
                rawDataWithHeader(ii,:) = tmp.';
            end
            fclose(udpReadDataObj);
            clear udpReadDataObj
        catch
            fclose(udpConfigObj);
            fclose(udpReadConfigObj);
            fclose(udpReadDataObj);
            error('data transfer with Matlab UDP failed');
            err = 1;
            return
        end
    end
    
    %% Stop DCA1000EVM
    try
        udpCMD = hex2dec(RECORD_STOP_CMD_CODE);
        fwrite(udpConfigObj,udpCMD,'uint8');
        response = fread(udpReadConfigObj,8,'uint8');
        
        if response ~= hex2dec(RECORD_STOP_CMD_RESP)
            fclose(udpConfigObj);
            fclose(udpReadConfigObj);
            error('DCA1000 error: Stop Record failed');
        end
    catch
        fclose(udpConfigObj);
        fclose(udpReadConfigObj);
        error('DCA1000 error: Stop Record failed');
    end
    
    %         TimeValuesLabel.Text = [TimeValuesLabel.Text  sprintf('%0.3f \n',toc) ];
    %         ReadyLabel.Text = 'Parsing...';
    %         ReadyLabel.FontColor = 'k';
    %         drawnow
    
    %--------------------------------------------------------------------------------------------------------------------------------
    tic
    
    rawData = zeros(numDatagramsProFrame,numMaxByteProDatagram,'uint8');
    
    for jj = 1:numDatagramsProFrame
        datagramNr = typecast(rawDataWithHeader(jj,1:4),'uint32');
        if datagramNr > numDatagramsProFrame
            error('Unexpected high Datagram number in Data Header.','Calculations stop. Please restart App and Radar');
            err = 1;
            return
        end
        rawData(datagramNr,:) = rawDataWithHeader(jj,11:end);
    end
    rawData = reshape(rawData.',[],1);
    
    % aus dem langen Datenstrom die Daten so umformen, dass pro Emfpangsantenne
    % ein langer Datenstrom entsteht
    matRX = readDCA1000(rawData,numSamp,numRX);
    
    % neuen Frame an alte Frames zum Abspeichern anhaengen
    rawDataAllFrames = [rawDataAllFrames, matRX];
    
    %% Daten in MIMO umwandeln
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
    
    messdaten = [messdaten ; matMIMO];
    
    % ggf. Static Clutter Removal
    if CBstaticRemoval
        fprintf('Static Clutter Remove');
        for ii =1:12
            for cc = 1:32
                matMIMO(cc,ii,:) = squeeze(matMIMO(cc,ii,:)) - mean(squeeze(matMIMO(cc,ii,:)));
            end
            for rr = 1:273
                matMIMO(:,ii,rr) = squeeze(matMIMO(:,ii,rr)) - mean(squeeze(matMIMO(:,ii,rr)));
            end
        end
    end
    %--------------------------------------------------------------------------------------------------------------------------------
    tic
end
%% Clean-Up
fclose(udpConfigObj);
fclose(udpReadConfigObj);
clear serObj udpConfigObj udpConfigObj
end

