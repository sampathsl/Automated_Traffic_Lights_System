function [Status,Exception,cacledMinObjY,numberOfVehicles] = CameraThreeSystemVehicleDetection(numberOfFrames,threshold,unwantedBlobSize,trackMinBlobSize,backgroundImage,laneMarginData,isVehicleDrivingLeftSide)
    %laneMarginData [lllX(LanelowerleftXvalue) llrX lulX lurX lllY llrY
    %lulY lurY]
    %isVehicleDrivingLeftSide - driver point of view
    
    global vidObjectThree;
    global expFileThree;
    
    try
        Status = true;
        Exception = 'No Errors';
        cacledMinObjY = 1000;
        minObjY = 1000;
        previousY = 1000;
        numberOfVehicles = 0;
        %set background
        roadWithoutVehicles = imread(backgroundImage);
        
        %size measurement
        [rows columns numberOfColorBands] = size(roadWithoutVehicles);

        %convert image to double format
        roadWithoutVehiclesDouble = im2double(roadWithoutVehicles);

        %convert to gray scale
        roadWithoutVehiclesGray = rgb2gray(roadWithoutVehicles);

        %normalize the color scema
        misc = (roadWithoutVehiclesDouble(:,:,1)+roadWithoutVehiclesDouble(:,:,2)+roadWithoutVehiclesDouble(:,:,3));
        misc(misc==0) = 0.001;
        %normalize RGB
        roadWithoutVehiclesDouble(:,:,1) = roadWithoutVehiclesDouble(:,:,1)./misc;
        roadWithoutVehiclesDouble(:,:,2) = roadWithoutVehiclesDouble(:,:,2)./misc;
        roadWithoutVehiclesDouble(:,:,2) = roadWithoutVehiclesDouble(:,:,3)./misc;
 
         currentFrames = vidObjectThree.FramesAcquired;

        
        %rdRectangle = [laneMarginData(1,1) laneMarginData(1,2) laneMarginData(1,3) laneMarginData(1,4)];
        %upperXYPositions = [laneMarginData(2,1) laneMarginData(2,2)];
        %laneMarginData [lllX(LanelowerleftXvalue) llrX lulX lurX lllY llrY lulY lurY]
        
        rdRectangle = [laneMarginData(1,1) laneMarginData(1,7) (laneMarginData(1,2) - laneMarginData(1,1)) (laneMarginData(1,6) - laneMarginData(1,7))];
        upperXYPositions = [laneMarginData(1,3) laneMarginData(1,7)];

        while(vidObjectThree.FramesAcquired <= ( currentFrames + numberOfFrames))

            % Get the snapshot of the current frame
            currentImage = getsnapshot(vidObjectThree);
            
            %Resize the current image
            currentImage = imresize(currentImage , [480 640]);
            
            %convert current image to double
            roadWithVehiclesDouble = im2double(currentImage);

            %take the image difference
            colorNormalizedImageDiff = imabsdiff(roadWithVehiclesDouble,roadWithoutVehiclesDouble);

            %filter with thresh
            colorNormalizedImageDiff(colorNormalizedImageDiff < threshold) = 0;
            colorNormalizedImageDiff(colorNormalizedImageDiff >= threshold) = 1;

            %remove unwanted blobs
            colorNormalizedImageDiffRemUnBlobs = bwareaopen(colorNormalizedImageDiff,unwantedBlobSize);

            %dilated colorNormalizedImageDiffRemUnBlobs
            cndrubImageDilated = imdilate(colorNormalizedImageDiffRemUnBlobs,ones(9));

            %fill the hols of blobs
            cndrubidFilledHoles = imfill(cndrubImageDilated,'holes');

            %color normalized final
            colorNormalizeFinal = cndrubidFilledHoles;

            %convert current imag e to gray scale
            roadWithVehiclesGray = rgb2gray(currentImage);
            
            %gray scale difference
            grayDiffereneImage = imabsdiff(roadWithVehiclesGray,roadWithoutVehiclesGray);

            grayDiffereneImageDouble = im2double(grayDiffereneImage);

            grayDiffereneImageDouble(grayDiffereneImageDouble<(threshold)) = 0;
            grayDiffereneImageDouble(grayDiffereneImageDouble>=(threshold)) = 1;

            %remove unwanted blobs in gray difference image
            grayScaledImageDiffRemUnBlobs = bwareaopen(grayDiffereneImageDouble,unwantedBlobSize);

            %returning dilated image
            gsdrubImageDilated = imdilate(grayScaledImageDiffRemUnBlobs,ones(3));

            %fill the hols of blobs
            gsdrubidFilledHoles = imfill(gsdrubImageDilated,'holes');

            %gray scale final
            grayScaleFinal = gsdrubidFilledHoles;

            %finalize the total procedure
            finalRes(:,:,1) = colorNormalizeFinal(:,:,1).*grayScaleFinal;
            finalRes(:,:,2) = colorNormalizeFinal(:,:,2).*grayScaleFinal;
            finalRes(:,:,3) = colorNormalizeFinal(:,:,3).*grayScaleFinal;

            %collect rgb components
            finalImage = (finalRes(:,:,1) + finalRes(:,:,2) + finalRes(:,:,3));

            %label the blobs
            labeledImage = bwlabel(finalImage);

            % Get all the blob properties.  Can only pass in originalImage in version R2008a and later.
            blobMeasurements = regionprops(labeledImage, 'all');
            
            %image show;
            subplot(2,2,3),imshow(currentImage);
            hold on
            pause(0.001);
            %store the previous boundary box
            previousBlobsBoundaryBox = 0;
            %firstTime
            firstTime = 0;
            
            %hold on
            for object = 1:length(blobMeasurements)
                    
                blobBoundaryBox = blobMeasurements(object).BoundingBox;
                newBlobsBoundaryBox = blobBoundaryBox;
                blobCentroid = blobMeasurements(object).Centroid;
                blobArea = blobMeasurements(object).Area;
                pause(0.001);%reduce the speed and remove stucking imshow
                
                if(blobArea < ((rdRectangle(1,3)*rdRectangle(1,4))/2))
                    if(isVehicleDrivingLeftSide)
                        [Status Exception] = CheckBlobPositionLeft(rdRectangle,upperXYPositions,blobCentroid);
                    else
                        [Status Exception] =CheckBlobPositionRight(rdRectangle,upperXYPositions,blobCentroid);
                    end
                    if(Status)
                        sizeBlobsBoundaryBox = size(previousBlobsBoundaryBox);
                        if(firstTime == 0)   
                        numberOfVehicles = numberOfVehicles + 1;
                        minObjY = blobCentroid(1,2);
                        previousY = minObjY;
                        %because of MATH equation cacledMinObjY = rows -
                        %minObjY;
                        cacledMinObjY = rows - minObjY;
                        rectangle('Position',blobBoundaryBox,'EdgeColor','r','LineWidth',2);
                        plot(blobCentroid(1,1),blobCentroid(1,2), '-m+');
                        
                        txtNumberOfVehicles = text(blobCentroid(1,1)-10,blobCentroid(1,2)-10, strcat(num2str(numberOfVehicles)));
                        set(txtNumberOfVehicles, 'FontName', 'Arial', 'FontWeight', 'bold', 'FontSize', 14,'Color','yellow');
                        
                        previousBlobsBoundaryBox = blobBoundaryBox;
                        pause(0.001);%reduce the speed and remove stucking imshow
                        firstTime = firstTime + 1;
                        elseif(sizeBlobsBoundaryBox(1,2) ~= 1)  
                            % code for preventing the internal blob detection
                            if(((previousBlobsBoundaryBox(1,1) - 2) < newBlobsBoundaryBox(1,1) && ((previousBlobsBoundaryBox(1,1) + previousBlobsBoundaryBox(1,3)) + 2) > newBlobsBoundaryBox(1,1)) && ((previousBlobsBoundaryBox(1,2) - 2) < newBlobsBoundaryBox(1,2) && ((previousBlobsBoundaryBox(1,2) + previousBlobsBoundaryBox(1,4)) + 2) > newBlobsBoundaryBox(1,2)))
                            else
                                if(blobArea > trackMinBlobSize) 
                                    numberOfVehicles = numberOfVehicles + 1;
                                    previousBlobsBoundaryBox = blobBoundaryBox;
                                    
                                    minObjY = blobCentroid(1,2);
                                    
                                    txtNumberOfVehicles_ = text(blobCentroid(1,1)-10,blobCentroid(1,2)-10, strcat(num2str(numberOfVehicles)));
                                    set(txtNumberOfVehicles_, 'FontName', 'Arial', 'FontWeight', 'bold', 'FontSize', 14,'Color', 'yellow');
                                    
                                    rectangle('Position',blobBoundaryBox,'EdgeColor','r','LineWidth',2);
                                    plot(blobCentroid(1,1),blobCentroid(1,2), '-m+');
                                    pause(0.001);%reduce the speed and remove stucking imshow
                                    if(minObjY < previousY)
                                        previousY = minObjY;
                                        %because of MATH equation cacledMinObjY = rows -
                                        %minObjY;
                                        cacledMinObjY = rows - minObjY;
                                    end

                                end
                            end
                        end
                    end 
                    Status = true;
                else 
                    cacledMinObjY = 1000;
                    Status = false;
                    Exception = 'Blob Error';
                    numberOfVehicles = 0;
                end
            end 
            
            hold off

        end
        
        flushdata(vidObjectThree);
        
    catch exp

        Status = false;
        cacledMinObjY = 1000;
        numberOfVehicles = 0;
        flushdata(vidObjectThree);
        msgString = getReport(exp);
        Exception = msgString;
        ExceptionFunction(exp);  
        strDate = datestr(now);
        strobject = sprintf('%s -- %s\n',strDate,msgString);
        fid = fopen(expFileThree,'a');
        fprintf(fid, '%s\n', strobject);
        fclose(fid);
        
    end
end % end of if @ line 103

function [Status Exception] = CheckBlobPositionLeft(rdRectangle,upperXYPositions,blobCentroid)
    try
        Status = false;
        Exception = 'No Errors';
        if(blobCentroid(1,1) > rdRectangle(1,1) && blobCentroid(1,1) < (rdRectangle(1,1) + (rdRectangle(1,3)/2)))
            lengthMargin = ((upperXYPositions(1,1) - rdRectangle(1,1))*(rdRectangle(1,4) - (blobCentroid(1,2) - rdRectangle(1,2)))/rdRectangle(1,4));
            positionX = rdRectangle(1,1) + lengthMargin; 
            if(positionX < blobCentroid(1,1) && positionX > 0)
                Status = true;
            else
                Status = false;
            end
        end
    catch exMat
        %strExcep = sprintf('Ex Line:%s',exMat.stack);
        %disp(exMat.stack);
        Status = false;
        Exception = exMat;
    end
end



function [Status Exception] = CheckBlobPositionRight(rdRectangle,upperXYPositions,blobCentroid)
    try
        Status = false;
        Exception = 'No Errors';
        if(blobCentroid(1,1) > (rdRectangle(1,1) + (rdRectangle(1,3)/2)) && blobCentroid(1,1) < (rdRectangle(1,1) + (rdRectangle(1,3))))
            lengthMargin = ((upperXYPositions(1,1) - rdRectangle(1,1))*(rdRectangle(1,4) - (blobCentroid(1,2) - rdRectangle(1,2)))/rdRectangle(1,4));
            positionX = (rdRectangle(1,1) + rdRectangle(1,3)) - lengthMargin ;

            if(positionX > blobCentroid(1,1) && positionX > 0)
                Status = true;
            else
                Status = false;
            end
        end
    catch exMat
        %strExcep = sprintf('Ex Line:%s',exMat.stack);
        %disp(exMat.stack);
        Status = false;
        Exception = exMat;
    end
end

