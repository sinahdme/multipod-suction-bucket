function eta_t = group_eta_tension(eta_pair, is_tension)
% GROUP_ETA_TENSION  Per-bucket tension-side efficiency from the pairwise
% uplift-cone overlap matrix returned by GROUP_INTERACTION (info.eta_pair).
%
%   eta_t = group_eta_tension(eta_pair, is_tension)
%
% Only pairs in which BOTH buckets are in net tension interact; every other
% pair contributes a factor of 1. Called once per equilibrium iteration by
% the main scripts, after the tension/compression state of each bucket is
% known from the vertical displacements.
n = size(eta_pair, 1);
is_t = logical(is_tension(:)).';
eta_t = ones(1, n);
for i = 1:n
    if ~is_t(i), continue; end
    for j = 1:n
        if j ~= i && is_t(j)
            eta_t(i) = eta_t(i) * eta_pair(i, j);
        end
    end
end
end
