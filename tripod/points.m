function [first_s_end, first_s_end_in, first_s_end_fixed, first_s_end_fixed_in, ...
          Pile_first_s_end, Pile_first_s_end_fixed, ...
          r_Pile_first_s_end, r_Pile_first_s_end_fixed] = ...
    points(R_split, th1, dz, n, n_l, Q, varargin)
%
% USAGE (legacy, Euler angles):
%   points(R_split, th1, dz, n, n_l, Q, phi, theta, psi, Z_lid, l_b, l, ro_b, ri_b, r_pile)
%
% USAGE (new, rotation matrix):
%   points(R_split, th1, dz, n, n_l, Q, R, Z_lid, l_b, l, ro_b, ri_b, r_pile)

% --------- parse rotation input ----------
if numel(varargin{1}) == 1
    % Legacy: phi, theta, psi as separate scalars
    rotInput = [varargin{1}, varargin{2}, varargin{3}];
    Z_lid  = varargin{4};
    l_b    = varargin{5};
    l      = varargin{6};
    ro_b   = varargin{7};
    ri_b   = varargin{8};
    r_pile = varargin{9};
else
    % New: rotation matrix R (3x3)
    rotInput = varargin{1};
    Z_lid  = varargin{2};
    l_b    = varargin{3};
    l      = varargin{4};
    ro_b   = varargin{5};
    ri_b   = varargin{6};
    r_pile = varargin{7};
end

% --------- setup ----------
angles = linspace(0,360,n+1);
angles = angles(2:end);                     % n azimuths
ca = cosd(angles);  sa = sind(angles);

z_centers = -((0:n_l-1) + 0.5) * (l_b/n_l); % n_l ring centers (negative down)

% centers of each bucket in plan
cx = l*cosd(th1);  cy = l*sind(th1);

numNodes = n*n_l;

% --------- skirt nodes (outer/inner) in body frame ----------
first_s_end     = zeros(3, numNodes);
first_s_end_in  = zeros(3, numNodes);

idx = 1;
for j = 1:n_l
    zc = z_centers(j);
    x_outer = cx + ro_b*ca;   y_outer = cy + ro_b*sa;
    x_inner = cx + ri_b*ca;   y_inner = cy + ri_b*sa;

    first_s_end(:,     idx:idx+n-1) = [x_outer; y_outer; zc*ones(1,n)];
    first_s_end_in(:,  idx:idx+n-1) = [x_inner; y_inner; zc*ones(1,n)];
    idx = idx + n;
end

% --------- apply dz then transform to fixed frame ----------
first_s_end_mid    = first_s_end;    first_s_end_mid(3,:)    = first_s_end_mid(3,:)    - dz;
first_s_end_mid_in = first_s_end_in; first_s_end_mid_in(3,:) = first_s_end_mid_in(3,:) - dz;

first_s_end_fixed       = zeros(size(first_s_end));
first_s_end_fixed_in    = zeros(size(first_s_end_in));

for i = 1:numNodes
    first_s_end_fixed(:,i)    = transformation(first_s_end_mid(:,i),    Q, rotInput);
    first_s_end_fixed_in(:,i) = transformation(first_s_end_mid_in(:,i), Q, rotInput);
end

% --------- pile-tip ring (z = -l_b) ----------
Pile_first_s_end = zeros(3, n);
Pile_first_s_end(1,:) = cx + r_pile*ca;
Pile_first_s_end(2,:) = cy + r_pile*sa;
Pile_first_s_end(3,:) = -l_b;

% apply dz for fixed
Pile_first_s_end_mid = Pile_first_s_end;
Pile_first_s_end_mid(3,:) = Pile_first_s_end_mid(3,:) - dz;

Pile_first_s_end_fixed = zeros(size(Pile_first_s_end));
for i = 1:n
    Pile_first_s_end_fixed(:,i) = transformation(Pile_first_s_end_mid(:,i), Q, rotInput);
end

% --------- lid sliding nodes (between ri_b..ro_b, here via R_split) ----------
% We place nodes at the middle of each annular strip: R = R_split(jj)-dR/2
if numel(R_split) < 2
    error('R_split must have at least two entries.');
end
dR = R_split(2) - R_split(1);

numRad = numel(R_split) - 1;    % number of annular bands
numLid = n * numRad;

r_Pile_first_s_end        = zeros(3, numLid);
r_Pile_first_s_end_fixed  = zeros(3, numLid);

col = 1;
for jj = 2:numel(R_split)
    Rm = R_split(jj) - dR/2;
    x = cx + Rm*ca;
    y = cy + Rm*sa;
    z = -Z_lid * ones(1,n);              % body frame

    block = [x; y; z];
    r_Pile_first_s_end(:, col:col+n-1) = block;

    % apply dz then transform
    block(3,:) = block(3,:) - dz;
    for k = 1:n
        r_Pile_first_s_end_fixed(:, col+k-1) = transformation(block(:,k), Q, rotInput);
    end

    col = col + n;
end
end
