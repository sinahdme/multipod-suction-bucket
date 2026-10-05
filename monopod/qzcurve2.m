function [qb1] = qzcurve2(fi_end, tip_end, tip_end_fixed, gamma, n, thickness, Di, Do)
    % qzcurve2 calculates the resisting moment components qb1 for a suction bucket foundation.

    % Define properties for Nq interpolation
    properties_Nq = [15, 8; 20, 12; 25, 20; 30, 40; 35, 50];
    Nq = interp1(properties_Nq(:, 1), properties_Nq(:, 2), atand(2/3 * tand(fi_end)), 'linear');

    % Compute displacement (w) and ensure non-negative values
    w = max(0, abs(tip_end_fixed(3, :)) - abs(tip_end(3, :)));

    % Compute normalized displacement ratio (WoverD)
    WoverD = w / (thickness);

    % Interpolate qend_over_qb values
    properties_qb = [0, 0; 0.002, 0.25; 0.013, 0.5; 0.042, 0.75; 0.073, 0.9; 0.1, 1];
    qend_over_qb = min(1, interp1(properties_qb(:, 1), properties_qb(:, 2), WoverD, 'linear'));

    % Compute soil pressure and area
    sigma_p = -gamma * tip_end(3, :);
    area_pile = pi * (Di*thickness) / (n);

    % Compute final pile resistance
    qb1 = Nq .* sigma_p .* area_pile .* qend_over_qb;
end
