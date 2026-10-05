function ap_out = apdefiner_general(ap, KK, n, n_l)
% APDEFINER_GENERAL  Mirror ap coefficients from passive to active side
%
% Implements the concept from Xu et al. (2023): "Tension-side springs 
% adopt the same stress as their diametrically opposite compression-side 
% counterparts, mirrored across the axis normal to the loading direction."
%
% This function is direction-independent: it uses the actual p-y force
% distribution (KK) to identify passive and active sides automatically.
% Since KK is computed from Euler-angle displacements, it already reflects
% the correct passive/active zones for ANY loading direction, including
% the reversal above/below the rotation center.
%
% Logic per spring node:
%   - If KK(i) > 0  → passive side  → ap already correct from Eq.(9)
%   - If KK(i) = 0 AND KK(opposite) > 0  → active side  → copy ap from opposite
%   - If KK(i) = 0 AND KK(opposite) = 0  → neutral or inner node → ap unchanged
%
% Inputs:
%   ap    - [1 x n*n_l]  reduction factors from Eq.(9)
%   KK    - [1 x n*n_l]  absolute p-y spring forces (0 for deactivated)
%   n     - number of circumferential springs (must be even)
%   n_l   - number of layers along skirt
%
% Output:
%   ap_out - [1 x n*n_l]  corrected reduction factors
%
% Note: requires even n for diametrically opposite pairing.
%       This is consistent with the model's requirement for symmetric
%       spring distribution (see Appendix B sensitivity analysis).

    if mod(n, 2) ~= 0
        error('n must be even for diametric mirroring of ap coefficients.');
    end

    ap_out = ap;
    half_n = n / 2;

    for j = 1:n_l
        base = (j - 1) * n;

        for i = 1:n
            idx = base + i;

            % Diametrically opposite spring index
            opp_i   = mod(i - 1 + half_n, n) + 1;
            opp_idx = base + opp_i;

            % If this spring is on the active side (no p-y force)
            % and its opposite is on the passive side (has p-y force)
            % → mirror the ap value
            if KK(idx) == 0 && KK(opp_idx) > 0
                ap_out(idx) = ap(opp_idx);
            end
        end
    end
end
