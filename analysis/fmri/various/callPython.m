function callPython(scriptpath, arguments)
% Call a Python script with given arguments
    commandStr = ['python ' scriptpath ' ' arguments];
    [status, commandOut] = system(commandStr);
    if status==1
        fprintf('ERROR: Python call probably failed, return code is %d and error message:\n%s\n',int2str(status),commandOut);
    end
end
