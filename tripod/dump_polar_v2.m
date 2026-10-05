% DUMP_POLAR_V2  Tripod (Kim et al. 2014 geometry): moment-rotation and rotation centre for the load azimuths computed
% with the validated v2 script (RUN_CFG.tilt_dir), to polar_v2_data<SUF>.csv (dir_deg, theta_deg, M_MNm, H_MN,
% QX_over_S, QZ_over_L) and a text table polar_v2_table<SUF>.txt (M per azimuth at 0.5-4 deg, ratios to 0 deg, the
% rotation at which M(60) overtakes M(0), the 60 vs 180 deg symmetry check and the rotation centre at 1 and 4 deg).
% Azimuth convention: direction toward which the tower top moves; 0 deg = Kim et al. case (bucket 2 at 180 deg lifted);
% 60 and 180 deg = load toward a bucket (two buckets lifted). The 120-deg periodicity and the mirror symmetry about the
% axis through a bucket give the full 360-deg envelope from 0..60 deg; 60 and 180 deg are both computed as a check.
% SUF selects the run set and the output names (default ''):
%   ''      _icr_uy25 (0 deg) and _tilt{15,30,45,60,180}                       -> polar_v2_data.csv, polar_v2_table.txt
%   '_v41'  _fix_uy25_t0_v41 (0 deg) and _fix_tilt{15,30,45,60,180}_v41     -> polar_v2_data_v41.csv, polar_v2_table_v41.txt
if ~exist('SUF', 'var'), SUF = ''; end
dirs = [0 15 30 45 60 180];
if isempty(SUF), ttag = @(a) sprintf('_tilt%d', a); tag0 = '_icr_uy25'; else, ttag = @(a) sprintf('_fix_tilt%d%s', a, SUF); tag0 = ['_fix_uy25_t0' SUF]; end
runs = cell(numel(dirs), 2); for r = 1:numel(dirs), runs{r,1} = dirs(r); if dirs(r) == 0, runs{r,2} = ['kim_validation_results' tag0 '.mat']; else, runs{r,2} = ['kim_validation_results' ttag(dirs(r)) '.mat']; end; end
out = ['polar_v2_data' SUF '.csv']; fid = fopen(out, 'w'); fprintf(fid, 'dir_deg,theta_deg,M_MNm,H_MN,QX_over_S,QZ_over_L\n');
P = struct('dir', {}, 'th', {}, 'M', {}, 'qx', {}, 'qz', {});
for r = 1:size(runs, 1)
    if ~exist(runs{r,2}, 'file'), fprintf('missing %s\n', runs{r,2}); continue; end
    S = load(runs{r,2}, 'M_2', 'M_1', 'eccentricity', 'ddd', 'count', 'CENTE_OF_ROTATION', 'l', 'l_b');
    a = runs{r,1}*pi/180; c = S.count; Q = S.CENTE_OF_ROTATION(:,1:c); qx = (Q(1,:)*cos(a) + Q(2,:)*sin(a))/S.l; qz = Q(3,:)/S.l_b;
    H = S.M_1(1:c)/S.eccentricity/1e3;   % horizontal force [MN] (M_1 = H * eccentricity)
    for i = 1:c, fprintf(fid, '%d,%.4f,%.4f,%.4f,%.5f,%.5f\n', runs{r,1}, S.ddd(i), S.M_2(i)/1e3, H(i), qx(i), qz(i)); end
    k = find(abs(S.ddd(1:c) - 1) < 1e-6, 1); k4 = find(abs(S.ddd(1:c) - 4) < 1e-6, 1);
    fprintf('dir %3d: %d steps, M(1 deg) = %6.1f, M(4 deg) = %6.1f MNm\n', runs{r,1}, c, S.M_2(k)/1e3, S.M_2(k4)/1e3);
    P(end+1) = struct('dir', runs{r,1}, 'th', S.ddd(1:c), 'M', S.M_2(1:c)/1e3, 'qx', qx, 'qz', qz); %#ok<SAGROW>
end
fclose(fid); fprintf('polar v2 csv ok: %s\n', out);
% ---- text table (runs that exist) ----
Mat = @(p, t) interp1([0 p.th(:)'], [0 p.M(:)'], t);   % linear interpolation through the origin and the run's own steps
tt = [0.5 1 1.5 2 3 4]; tf = fopen(['polar_v2_table' SUF '.txt'], 'w'); ds = [P.dir]; i0 = find(ds == 0, 1); i60 = find(ds == 60, 1); i180 = find(ds == 180, 1);
fprintf(tf, 'Tripod multidirectional envelope (runs%s): M [MN.m] vs rotation for the load azimuths (0 deg = Kim et al. case, bucket 2 lifted)\n', SUF);
fprintf(tf, 'theta |'); for p = 1:numel(P), if P(p).dir == 180, fprintf(tf, ' M(180) check |'); else, fprintf(tf, ' M(%d) |', P(p).dir); end; end
if ~isempty(i60) && ~isempty(i0), fprintf(tf, ' M(60)/M(0)'); end; fprintf(tf, '\n');
for t = tt
    fprintf(tf, '%.1f |', t); for p = 1:numel(P), fprintf(tf, ' %.1f |', Mat(P(p), t)); end
    if ~isempty(i60) && ~isempty(i0), fprintf(tf, ' %.3f', Mat(P(i60), t)/Mat(P(i0), t)); end; fprintf(tf, '\n');
end
if ~isempty(i0)
    fprintf(tf, '\nRatio M(alpha)/M(0)\ntheta |'); for p = 1:numel(P), fprintf(tf, ' %d |', P(p).dir); end; fprintf(tf, '\n');
    for t = tt, fprintf(tf, '%.1f |', t); for p = 1:numel(P), fprintf(tf, ' %.3f |', Mat(P(p), t)/Mat(P(i0), t)); end; fprintf(tf, '\n'); end
    [mx, im] = max(arrayfun(@(p) Mat(p, 4), P)); fprintf(tf, 'largest M at 4 deg: %.1f MN.m at alpha = %d deg (%.3f x M(0))\n', mx, P(im).dir, mx/Mat(P(i0), 4));
    [mn, im] = min(arrayfun(@(p) Mat(p, 0.5), P(ds ~= 180))); Pn = P(ds ~= 180); fprintf(tf, 'smallest M at 0.5 deg: %.1f MN.m at alpha = %d deg (%.3f x M(0))\n', mn, Pn(im).dir, mn/Mat(P(i0), 0.5));
end
if ~isempty(i60) && ~isempty(i0)
    thf = linspace(0.03, 4, 3971); d60 = arrayfun(@(t) Mat(P(i60), t) - Mat(P(i0), t), thf); kf = find(d60 > 0, 1);
    if isempty(kf), fprintf(tf, 'M(60) stays below M(0) up to 4 deg\n'); elseif kf == 1, fprintf(tf, 'M(60) exceeds M(0) over the whole sweep\n');
    else, fprintf(tf, 'M(60) overtakes M(0) at theta = %.2f deg (linear interpolation between the sweep steps; M(60)/M(0) = %.3f at 0.5 deg, %.3f at 4 deg)\n', thf(kf), Mat(P(i60), 0.5)/Mat(P(i0), 0.5), Mat(P(i60), 4)/Mat(P(i0), 4)); end
end
if ~isempty(i60) && ~isempty(i180)
    dd = abs(P(i60).M - P(i180).M)./P(i60).M*100; fprintf(tf, '60 vs 180 deg symmetry check: max |M(60)-M(180)|/M(60) = %.2f %% (at %.2f deg), %.2f %% at 4 deg\n', max(dd), P(i60).th(find(dd == max(dd), 1)), dd(end));
end
fprintf(tf, '\nRotation centre (QX/S along the load direction, QZ/L) at 1 and 4 deg\nalpha | QX/S(1) QZ/L(1) | QX/S(4) QZ/L(4)\n');
for p = 1:numel(P), k1 = find(abs(P(p).th - 1) < 1e-6, 1); k4 = find(abs(P(p).th - 4) < 1e-6, 1); fprintf(tf, '%d | %.3f %.3f | %.3f %.3f\n', P(p).dir, P(p).qx(k1), P(p).qz(k1), P(p).qx(k4), P(p).qz(k4)); end
fclose(tf); type(['polar_v2_table' SUF '.txt']);
