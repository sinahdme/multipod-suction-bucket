function R = rodrigues_rotation(dd, alpha_deg)
% RODRIGUES_ROTATION  Build rotation matrix for a tilt of magnitude dd
%                     (radians) in the direction alpha_deg (degrees).
%
%   R = rodrigues_rotation(dd, alpha_deg)
%
%   Convention matches the original Euler-based code:
%       alpha=0   -> tower tilts toward -x
%       alpha=90  -> tower tilts toward -y
%       alpha=45  -> tower tilts toward (-x,-y), i.e. 225 deg
%
%   Unlike the old Euler decomposition (phi,theta about fixed axes),
%   this uses a single axis-angle rotation (Rodrigues formula), which
%   preserves the correct tilt-direction symmetry for all alpha values.
%
%   The rotation axis is perpendicular to the tilt direction:
%       n = [-sind(alpha_deg), cosd(alpha_deg), 0]

    n = [-sind(alpha_deg); cosd(alpha_deg); 0];

    K = [  0,   -n(3),  n(2);
         n(3),    0,   -n(1);
        -n(2),  n(1),    0  ];

    % Standard Rodrigues, then TRANSPOSE to match the original code's
    % convention (R_psi' * R_theta' * R_phi' used transposed matrices).
    R_std = eye(3)*cos(dd) + (1 - cos(dd))*(n*n') + sin(dd)*K;
    R = R_std';
end
