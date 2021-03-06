classdef Reformatter < handle
    %REFORMATTER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Constant)
        extension = 'png'
    end

    methods
        function reformatDataset(obj, sourcePath, sceneDirPattern, targetPath, imgCopy)
            if nargin < 5
                imgCopy = true;
            end
            
            % find sub paths under sourcePath that includes image frames
            subPathList = obj.findSourceDirList(sourcePath, sceneDirPattern)
            listLen = length(subPathList);

            for i=1:listLen
                rawScenePath = char(subPathList(i));
                dstPath = char(strrep(rawScenePath, sourcePath, targetPath));
                % create subdirs and files
                obj.preparePath(dstPath, imgCopy);
                
                % the order of following functions MATTERS. Do NOT change it.
                % copy text file containing camera parameters
                obj.copyCameraParam(rawScenePath, dstPath)
                % convert rgb, depth, and pose into unified format
                % and copy them into dstPath
                [depthFiles, rgbFiles, poses] = obj.getSyncronizedFrames(rawScenePath);
                if imgCopy
                    obj.moveImages(depthFiles, 'depth', dstPath)
                    obj.moveImages(rgbFiles, 'rgb', dstPath)
                end
                obj.writePoses(poses, dstPath)
            end
        end
    end


    methods (Access = protected)
        function subpaths = findSourceDirList(obj, rootPath, dirPattern)
            % list all dirs and files in rootPath recursively
            list = dir(fullfile(rootPath, dirPattern));
            % extract dirs only
            list = list(cell2mat({list.isdir}));
            % remove . and ..
            list = list(~cellfun(@(x) endsWith(x, '.'), {list.name}));
            % make cell array of full paths
            subpaths = arrayfun(@(x) fullfile(x.folder, x.name), list, ...
                                'UniformOutput', false);
        end


        function preparePath(obj, parentDir, cleanDir)
            obj.cleanAndMakeDirs(parentDir, cleanDir);
            ['create ', parentDir]
            obj.cleanAndMakeDirs(fullfile(parentDir, 'rgb'), cleanDir);
            obj.cleanAndMakeDirs(fullfile(parentDir, 'depth'), cleanDir);
            
            fid = fopen(fullfile(parentDir, 'poses.txt'), 'w');
            fclose(fid);
        end
        
        function cleanAndMakeDirs(obj, dirname, cleanDir)
            if exist(dirname, 'dir') && cleanDir
                rmdir(dirname, 's')
            end
            pause(0.1)
            if ~exist(dirname, 'dir')
                mkdir(dirname);
            end
        end

        function moveImages(obj, imgList, imgType, dstPath)
            listLen = length(imgList);
            prinInterv = max(floor(listLen/10), 100);
            prinInterv = round(prinInterv/100)*100;

            tic
            for i=1:listLen
                srcfile = char(imgList(i));
                if mod(i, prinInterv)==0
                    sprintf('copying %s... %d in %d, took %.1fs\n%s', ...
                        imgType, i, listLen, toc, srcfile)
                    tic
                end

                dstfile = fullfile(dstPath, imgType, sprintf('%s-%05d.%s', imgType, i, obj.extension));
                obj.moveImgFile(imgType, srcfile, dstfile);
            end
        end


        function writePoses(obj, poses, dstPath)
            try
                filename = fullfile(dstPath, 'poses.txt');
                fid = fopen(filename, 'w');
                assert(fid>=0, 'Reformatter:writePoses:cannotOpenFile', filename);
                fprintf(fid, '%.4f %.4f %.4f %.4f %.4f %.4f %.4f\n', poses');
                fclose(fid);
            catch ME
                sprintf('convertAndMovePoses:\n%s\n%s', ME.identifier, ME.message)
            end
        end


        function pose = convertTransformMatToVector(obj, tmat)
            assert(size(tmat,1)==4 && size(tmat,2)==4 && abs(det(tmat(1:3,1:3))-1) < 0.001, ...
                'Reformatter:convertTransformMatToVector:wrongTMatFormat', ...
                'invalid transformation matrix')
            quat = rotm2quat(tmat(1:3,1:3));
            assert(abs(norm(quat,2)-1) < 1e-5)
            posi = tmat(1:3,4)';
            pose = [posi, quat];
        end

        function fileCopy(obj, srcfile, dstfile, funcname)
            [success, msg, msgid] = copyfile(srcfile, dstfile);
            if success == 0
                sprintf('%s:\n%s\n%s', funcname, msgid, msg)
            end
        end


    end


    % methods to be overriden in ReformatUnregistered
    methods (Access = protected)
        function copyCameraParam(obj, rawScenePath, dstPath)
            % fullpath of dir of current m-file
            [pathstr, ~, ~] = fileparts(mfilename('fullpath'));
            try
                srcCameraParam = fullfile(pathstr, 'cameraParams', ...
                                    obj.getCameraFileName(rawScenePath));
                dstCameraParam = fullfile(dstPath, 'camera_param.txt');
                obj.fileCopy(srcCameraParam, dstCameraParam, 'copyCameraParam');
            catch ME
                sprintf('copyCameraParam:\n%s\n%s', ME.identifier, ME.message)
            end
        end

        function moveImgFile(obj, imgType, srcfile, dstfile)
            if endsWith(srcfile, obj.extension)
                obj.fileCopy(srcfile, dstfile, 'convertAndMoveImgs');
            else
                try
                    img = imread(srcfile);
                    imwrite(img, dstfile)
                catch ME
                    sprintf('convertAndMoveImgs:\n%s\n%s', ME.identifier, ME.message)
                end
            end
        end
    end


    % methods to be implemented in subclasses
    methods (Abstract, Access = protected)
        cameraFile = getCameraFileName(obj, rawScenePath)
        [depthFiles, rgbFiles, poses] = getSyncronizedFrames(obj, scenePath)
    end
end
