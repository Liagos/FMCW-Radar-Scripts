
clear ’all’ 
close ’all’

series = 1;
measurementsData = strcat('testReadDataResult',num2str(series),'.mat');
load (measurementsData);
indexVar = ones(size(testReadDataResult));

indexVar (6) = 2;
indexVar (10) = 2;
indexVar (11) = 2;
indexVar (15)= 2;

normDiff = zeros(1,15); 
diff = zeros(15,2);

for i = 1:15 
    figure(1);
    hold on
    tV = testReadDataResult(i).translationVector; 
    plot(tV(1),tV(3),'bo');
    rAng = testReadDataResult(i).maxAngl(indexVar(i));
    rDist = testReadDataResult(i).maxDist(indexVar(i));
    plot (rDist*sind(rAng),rDist*cosd(rAng),'r+') 
    diff(i,:) = [tV(1),tV(3)] - [rDist*sind(rAng), rDist*cosd(rAng)];
    normDiff(i) = norm(diff(i,:)); 
    legend('Checkerboard','Corner Reflector');
end
figure(2);
plot(normDiff ,'g*');
limit = 0.6;
idx= find (normDiff < limit); dx = mean(diff(idx ,:) ,1);

for i = 1:15 
    figure(3);
    hold on
    tV = testReadDataResult(i).translationVector; 
    plot(tV(1),tV(3),'bo');
    rAng = testReadDataResult(i).maxAngl(indexVar(i));
    rDist = testReadDataResult(i).maxDist(indexVar(i));
    plot (rDist*sind(rAng)+dx(1),rDist*cosd(rAng)+dx(2),'r+')
    diff(i,:) = [tV(1),tV(3)] - [rDist*sind(rAng)+dx(1),rDist*cosd(rAng)+dx(2)]; 
    normDiff(i) = norm(diff(i,:)); 
    legend('Checkerboard','Corner Reflector');
end

figure(4); 
plot(normDiff ,'g*');