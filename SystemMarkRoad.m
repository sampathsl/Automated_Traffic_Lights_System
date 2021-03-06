% clc;	% Clear command window.
% clear;	% Delete all variables.
% close all;	% Close all figure windows except those created by imtool.
% imtool close all;	% Close all figure windows created by imtool.

function [Status,Exception,RoadMargins,LaneMargins,Distance] = SystemMarkRoad(fullImageFileName,numberOfLanes,smallestAcceptableYellowArea,roadWidthRatio,metersBetweenYellowBars,metersLeftedToRoad,cameraID,roadCoveringDistance)

    try
    Exception = 'No Errors';
    % Read in image into an array.
    [rgbImage storedColorMap] = imread(fullImageFileName);
    [rows columns numberOfColorBands] = size(rgbImage);
    % If it's monochrome (indexed), convert it to color.
    % Check to see if it's an 8-bit image needed later for scaling).
    if strcmpi(class(rgbImage), 'uint8')
        % Flag for 256 gray levels.
        eightBit = true;
    else
        eightBit = false;
    end
    if numberOfColorBands == 1
        if isempty(storedColorMap)
            % Just a simple gray level image, not indexed with a stored color map.
            % Create a 3D true color image where we copy the monochrome image into all 3 (R, G, & B) color planes.
            rgbImage = cat(3, rgbImage, rgbImage, rgbImage);
        else
            % It's an indexed image.
            rgbImage = ind2rgb(rgbImage, storedColorMap);
            % ind2rgb() will convert it to double and normalize it to the range 0-1.
            % Convert back to uint8 in the range 0-255, if needed.
            if eightBit
                rgbImage = uint8(255 * rgbImage);
            end
        end
    end

    %rgbImage = imresize(rgbImage,0.5);
    %rgbImage = imresize(rgbImage , [480 640]);

    % Convert RGB image to HSV
    hsvImage = rgb2hsv(rgbImage);
    % Extract out the H, S, and V images individually
    hImage = hsvImage(:,:,1);
    sImage = hsvImage(:,:,2);
    vImage = hsvImage(:,:,3);

    hueThresholdLow = 0;
    hueThresholdHigh = graythresh(hImage);
    saturationThresholdLow = graythresh(sImage);
    saturationThresholdHigh = 1.0;
    valueThresholdLow = graythresh(vImage);
    valueThresholdHigh = 1.0;

    % Now apply each color band's particular thresholds to the color band
    hueMask = (hImage >= hueThresholdLow) & (hImage <= hueThresholdHigh);
    saturationMask = (sImage >= saturationThresholdLow) & (sImage <= saturationThresholdHigh);
    valueMask = (vImage >= valueThresholdLow) & (vImage <= valueThresholdHigh);

    % Combine the masks to find where all 3 are "true."
    % Then we will have the mask of only the red parts of the image.
    yellowObjectsMask = uint8(hueMask & saturationMask & valueMask);


    % Tell user that we're going to filter out small objects.
    %smallestAcceptableArea = 150; % Keep areas only if they're bigger than this.

    % Get rid of small objects.  Note: bwareaopen returns a logical.
    yellowObjectsMask = uint8(bwareaopen(yellowObjectsMask, smallestAcceptableYellowArea));


    % Smooth the border using a morphological closing operation, imclose().
    structuringElement = strel('disk', 4);
    %structuringElement = strel('disk', 8);
    yellowObjectsMask = imclose(yellowObjectsMask, structuringElement);

    % Fill in any holes in the regions, since they are most likely red also.
    yellowObjectsMask = uint8(imfill(yellowObjectsMask, 'holes'));

    % You can only multiply integers if they are of the same type.
    % (yellowObjectsMask is a logical array.)
    % We need to convert the type of yellowObjectsMask to the same data type as hImage.
    yellowObjectsMask = cast(yellowObjectsMask, class(rgbImage));

    % Use the yellow object mask to mask out the yellow-only portions of the rgb image.
    maskedImageR = yellowObjectsMask .* rgbImage(:,:,1);
    maskedImageG = yellowObjectsMask .* rgbImage(:,:,2);
    maskedImageB = yellowObjectsMask .* rgbImage(:,:,3);

    % Concatenate the masked color bands to form the rgb image.
    maskedRGBImage = cat(3, maskedImageR, maskedImageG, maskedImageB);
    
    %imtool(maskedRGBImage);

    boundaries = bwboundaries(rgb2gray(imclose(maskedRGBImage,ones(3))));

    bndrSize = size(boundaries);

    f = figure('visible','off');
    image(rgbImage)
    hold on
    
    objXY = 0;
    dataRect = 0;
    
    
    if (numberOfLanes == 2)

        for k = 1:bndrSize(1)
            bnd = boundaries{k};
            RB2 = max(bnd);
            LT2 = min(bnd);
            objXY(k,1) = (LT2(2)+((RB2(2)-LT2(2))/2));
            objXY(k,2) = (LT2(1)+((RB2(1)-LT2(1))/2));
            dataRect(k,1) = RB2(2);
            dataRect(k,2) = LT2(1);
            dataRect(k,3) = LT2(2);
            dataRect(k,4) = RB2(1);
        end

          sizeData = size(dataRect);
          sizeobjXY = size(objXY);
            
        if(sizeData(1) ~= 1 && sizeobjXY(1) ~= 1 && sizeData(2) ~= 1 && sizeobjXY(2) ~= 1)
            
            VEC1 = max(dataRect);
            VEC2 = min(dataRect);
            
            %set 2.2 width to smooth the road and vector set perfect manner
            Status = (VEC1(3) - VEC2(1)) < ((VEC1(1) - VEC2(3))/ roadWidthRatio);
            if (Status)

                x = [VEC2(1),VEC1(3),VEC1(1),VEC2(3),VEC2(1)];
                y = [VEC2(2),VEC2(2),VEC1(4),VEC1(4),VEC2(2)];
                plot(x,y,'--rs','LineWidth',2,'MarkerEdgeColor','k','MarkerFaceColor','g','MarkerSize',10);
                RoadMargins = [x,y];

                xx = [VEC2(1),(VEC2(1)+(((VEC1(3) - VEC2(1))/2)-2)),(VEC2(3)+(((VEC1(1)-VEC2(3))/2))-2),VEC2(3),VEC2(1)];
                yy = [VEC2(2),VEC2(2),VEC1(4),VEC1(4),VEC2(2)];
                b = text(VEC2(1)-10,VEC2(2)-10, strcat('Lane: ', num2str(1)));
                set(b, 'FontName', 'Arial', 'FontWeight', 'bold', 'FontSize', 12,'Color', 'red');
                plot(xx,yy,'--gs','LineWidth',2,'MarkerEdgeColor','k','MarkerFaceColor','g','MarkerSize',10);
                LaneOneMargins = [xx,yy];


                xxx = [(VEC2(1)+(((VEC1(3) - VEC2(1))/2)+2)),VEC1(3),VEC1(1),(VEC2(3)+(((VEC1(1)-VEC2(3))/2))+2),(VEC2(1)+(((VEC1(3) - VEC2(1))/2)+2))];
                yyy = [VEC2(2),VEC2(2),VEC1(4),VEC1(4),VEC2(2)];
                c = text((VEC2(1)+(((VEC1(3) - VEC2(1))/2)+2))-10,VEC2(2)-10, strcat('Lane: ', num2str(2)));
                set(c, 'FontName', 'Arial', 'FontWeight', 'bold', 'FontSize', 12,'Color', 'red');
                plot(xxx,yyy,'--gs','LineWidth',2,'MarkerEdgeColor','k','MarkerFaceColor','g','MarkerSize',10);
                LaneTwoMargins = [xxx,yyy];

                LaneMargins =[LaneOneMargins;LaneTwoMargins];

                objXY = twoDSort(objXY);

                x = 1;
                meters = 0;
                
                meters = meters + metersLeftedToRoad;
                
                strDistance = strcat(['Cam_',num2str(cameraID),'_Distance_Data','.txt']);
                fid = fopen(strDistance,'w');
                str_Data = strcat([num2str(0),',',num2str(columns/2),',',num2str(0)]);
                fprintf(fid, '%s\n', str_Data);
                for m = 1:k
                    if objXY(m,1) > VEC2(1) + 10 && objXY(m,1) < VEC1(3) - 10
                        meters = meters + metersBetweenYellowBars ;
                        midXY(x,1) = objXY(m,1);
                        midXY(x,2) = objXY(m,2);
                        X(1,1) = midXY(x,1)+50;
                        X(1,2) = midXY(x,1)-50;
                        Y(1,1) = midXY(x,2);
                        Y(1,2) = midXY(x,2);
                        line(X,Y,'Color','r','LineWidth',2);
                        str = strcat([num2str(meters),'m']);
                        a = text(midXY(x,1)-10,midXY(x,2)-10, strcat('Meters: ', num2str(str)));
                        set(a, 'FontName', 'Arial', 'FontWeight', 'bold', 'FontSize', 12,'Color', 'red');
                        %Distance = [meters midXY(x,1) midXY(x,2);];
                        
                        if(rows - midXY(x,2) > 0)
                            Distance(x,1) = meters;
                            Distance(x,2) = midXY(x,1);
                            Distance(x,3) = rows - midXY(x,2); % interchange because of MATH equation
                            str_Data = strcat([num2str(meters),',',num2str(midXY(x,1)),',',num2str(rows - midXY(x,2))]);
                            % num2str(rows - midXY(x,2)) ---> because of MATHS
                            % Equation
                            fprintf(fid, '%s\n', str_Data);
                        end
                        %plot(midXY(x,1)+50,midXY(x,2),midXY(x,1)-50,midXY(
                        %x,2),'--bs','LineWidth',2,'MarkerEdgeColor','k','MarkerFaceColor','g','MarkerSize',10);
                        x = x+1;
                    end
                end
                
                str_Data = strcat([num2str(roadCoveringDistance),',',num2str(columns/2),',',num2str(rows)]);
                fprintf(fid, '%s\n', str_Data);
                
                fclose(fid);
                
                set(gca, 'visible', 'off', 'position', [0 0 1 1]);
                str = strcat(['Cam_',num2str(cameraID),'_System_Drawn','.png']);
                print(f,'-r80','-dpng', str);

            else
                Status = false;
                RoadMargins = 0;
                LaneMargins = 0;
                Distance = 0;
                strException = sprintf('Does not support set %f width ratio to smooth the road and vector set perfect manner',roadWidthRatio);
                Exception = strException;
            end
            
        else
            
            Status = false;
            RoadMargins = 0;
            LaneMargins = 0;
            Distance = 0;
            strException = sprintf('Does not support set %f width ratio to smooth the road and vector set perfect manner',roadWidthRatio);
            Exception = strException;
            
        end
        
    else
        
        %number of lanes 3 ...
        
    end
    catch exp
        %disp(Exception.stack);
        RoadMargins = 0;
        LaneMargins = 0;
        Distance = 0;
        Status = false;
        msgString = getReport(exp);
        Exception = msgString;
        ExceptionFunction(exp);
        
    end % end of if @ line 103

end % from ExtractYellow()


function sortedTwoDArray = twoDSort(twoDArray)
    [oneD twoD] = size(twoDArray);
    for  numF = 1:oneD
        for numS = 1:(oneD - 1)
            if(twoDArray(numS,2) < twoDArray(numS + 1,2))
                tempXY1 = twoDArray(numS,1);
                tempXY2 = twoDArray(numS,2);
                twoDArray(numS,1) = twoDArray(numS + 1,1);
                twoDArray(numS + 1,1) = tempXY1;
                twoDArray(numS,2) = twoDArray(numS + 1,2);
                twoDArray(numS + 1,2) = tempXY2;
            end
        end
    end
    sortedTwoDArray = twoDArray;
end


    




