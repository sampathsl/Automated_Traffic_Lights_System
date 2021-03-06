function [Status,Exception] = RoadDistance(fullImageFileName,roadPostions,meters,metersLeftedToRoad,cameraID)
try
    rgbImage = imread(fullImageFileName);
    [arrayIndex positions] = size(roadPostions);
    f = figure('visible','off');
    image(rgbImage)
    hold on
    
    Status = (positions > 0);
    dMeters = 0;
    dMeters = dMeters + metersLeftedToRoad;
    if(Status) 
        sortedTwoDArray = twoDSort(roadPostions);
        for m = 1:2:(positions - 1)
            dMeters = dMeters + meters;
            X = sortedTwoDArray(1,m);
            Y = sortedTwoDArray(1,m+1);
            xLine = [(X-10) (X+10)];
            yLine = [Y Y];
            line(xLine,yLine,'Color','b','LineWidth',2);
            str = strcat([num2str(dMeters),'m']);
            a = text(X,Y-10, num2str(str));
            set(a, 'FontName', 'Arial', 'FontWeight', 'bold', 'FontSize',12,'Color', 'red');
        end
    end
    
    set(gca, 'visible', 'off', 'position', [0 0 1 1]);
    str = strcat(['Cam_',num2str(cameraID),'_M_Final_Road_Drawn','.png']);
    print(f,'-r80','-dpng', str);
    Exception = 'No Errors';
    
catch exp
    
    Status = false;
    msgString = getReport(exp);
    Exception = msgString;
    ExceptionFunction(exp);
    
end
end


function sortedTwoDArray = twoDSort(twoDArray)
    [oneD twoD] = size(twoDArray);
    for  numF = 1:oneD
        for numS = 1:(oneD - 1)
            val1 = twoDArray(numS,2);
            val2 = twoDArray((numS+1),2);
            if(val1 > val2)
                tempXY1 = twoDArray(numS,1);
                tempXY2 = twoDArray(numS,2);
                twoDArray(numS,1) = twoDArray((numS+1),1);
                twoDArray((numS+1),1) = tempXY1;
                twoDArray(numS,2) = twoDArray((numS+1),2);
                twoDArray((numS+1),2) = tempXY2;
            end
        end
    end
    sortedTwoDArray = twoDArray;
end