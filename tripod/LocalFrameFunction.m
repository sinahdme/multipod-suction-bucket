function [new_position] = LocalFrameFunction(translation_vector,Theta)

% Translation vector (moving the local frame from the origin) like translation_vector = [10; 0; 0]

% Define the rotation matrix (rotation around the Z-axis)
rotation_matrix = [cosd(Theta) -sind(Theta) 0;
                   sind(Theta)  cosd(Theta) 0;
                   0           0          1];

% Create the homogeneous translation matrix
translation_matrix = [1 0 0 translation_vector(1);
                      0 1 0 translation_vector(2);
                      0 0 1 translation_vector(3);
                      0 0 0 1];

% First, translate the local frame
local_origin_translated = translation_matrix * [0; 0; 0; 1];

% Then, rotate the translated local frame
new_position_global_homogeneous = rotation_matrix * local_origin_translated(1:3);

% Convert back to Cartesian coordinates
new_position_global = [new_position_global_homogeneous; 1];

% Display the new position of the local origin in global coordinates
new_position = new_position_global(1:3);

end