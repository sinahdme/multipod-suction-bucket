function transformedPoint = transformation(P, Q, rotInput)
% TRANSFORMATION  Rotate point P about center Q.
%
%   transformedPoint = transformation(P, Q, [phi, theta, psi])
%       Legacy Euler-angle mode (3-element vector).
%       Builds R = R_psi' * R_theta' * R_phi'.
%
%   transformedPoint = transformation(P, Q, R)
%       Direct rotation-matrix mode (3x3 matrix).
%       Uses R directly — no Euler decomposition needed.

    if numel(rotInput) == 3
        % -------- Legacy: Euler angles --------
        phi   = rotInput(1);   % Roll  (X-axis)
        theta = rotInput(2);   % Pitch (Y-axis)
        psi   = rotInput(3);   % Yaw   (Z-axis)

        R_phi = [1, 0, 0;
                 0, cos(phi), -sin(phi);
                 0, sin(phi),  cos(phi)];

        R_theta = [ cos(theta), 0, sin(theta);
                    0,          1, 0;
                   -sin(theta), 0, cos(theta)];

        R_psi = [cos(psi), -sin(psi), 0;
                 sin(psi),  cos(psi), 0;
                 0,         0,        1];

        R = R_psi' * R_theta' * R_phi';
    else
        % -------- New: rotation matrix passed directly --------
        R = rotInput;
    end

    P_translated = P - Q;
    transformedPoint = (R * P_translated) + Q;
end
