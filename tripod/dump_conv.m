% DUMP_CONV  Discretisation convergence of the tripod (Kim et al. 2014 case, 18-step sweep, azimuth 0): the moment-rotation
% curves of the RUN_CFG.n / RUN_CFG.n_l override runs, to conv<SUF>.csv (family, n, n_l, theta_deg, M_MNm) and a text
% table conv<SUF>_table.txt (M at 0.5/1/2/4 deg vs n and vs n_l with the % change relative to the finest mesh, the
% largest |% change| over all 18 steps, and the queue wall time when CONV_LOG points at the queue.log of the runs).
% Families: 'n'  = n strips per circumference 8/16/24/32/40 at n_l = 25 (n = 40 is the u_y = 2.5 mm reference run);
%           'nl' = n_l levels 5/10/15/20/25 at n = 40 (n_l = 25 is the same reference run, written under both families);
%           'combo' = n = n_l = 16 (the discretisation of the tetrapod runs).
% SUF selects the run set and the output names (default ''); CONV_LOG (optional) = path of the queue log with
% '<job> start HH:MM' / '<job> ok HH:MM' lines (jobs C1_kim_conv_n8_nl25 ... K1_kim_uy25_t0), else ''.
%   '_v41'  kim_validation_results_fix_conv_n<n>_nl<n_l>_v41.mat + _fix_uy25_t0_v41 -> conv_v41.csv, conv_v41_table.txt
if ~exist('SUF', 'var'), SUF = ''; end
if ~exist('CONV_LOG', 'var'), CONV_LOG = ''; end
if isempty(SUF), ctag = @(n, nl) sprintf('_conv_n%d_nl%d', n, nl); tag0 = '_icr_uy25'; else, ctag = @(n, nl) sprintf('_fix_conv_n%d_nl%d%s', n, nl, SUF); tag0 = ['_fix_uy25_t0' SUF]; end
nref = 40; nlref = 25;
runs = cell(0, 5);   % family, n, n_l, tag, queue job id
for n = [8 16 24 32], runs(end+1,:) = {'n', n, nlref, ctag(n, nlref), sprintf('kim_conv_n%d_nl%d', n, nlref)}; end %#ok<SAGROW>
runs(end+1,:) = {'n', nref, nlref, tag0, 'kim_uy25_t0'};
for nl = [5 10 15 20], runs(end+1,:) = {'nl', nref, nl, ctag(nref, nl), sprintf('kim_conv_n%d_nl%d', nref, nl)}; end %#ok<SAGROW>
runs(end+1,:) = {'nl', nref, nlref, tag0, 'kim_uy25_t0'};
runs(end+1,:) = {'combo', 16, 16, ctag(16, 16), 'kim_conv_n16_nl16'};
logtxt = ''; if ~isempty(CONV_LOG) && exist(CONV_LOG, 'file'), logtxt = fileread(CONV_LOG); end
out = ['conv' SUF '.csv']; fid = fopen(out, 'w'); fprintf(fid, 'family,n,n_l,theta_deg,M_MNm\n');
C = struct('fam', {}, 'n', {}, 'nl', {}, 'th', {}, 'M', {}, 'wall', {});
for r = 1:size(runs, 1)
    f = ['kim_validation_results' runs{r,4} '.mat']; if ~exist(f, 'file'), fprintf('missing %s\n', f); continue; end
    S = load(f, 'M_2', 'ddd', 'count', 'n', 'n_l'); c = S.count;
    if S.n ~= runs{r,2} || S.n_l ~= runs{r,3}, fprintf('WARNING %s: saved n = %d, n_l = %d, expected %d / %d\n', f, S.n, S.n_l, runs{r,2}, runs{r,3}); end
    for i = 1:c, fprintf(fid, '%s,%d,%d,%.4f,%.4f\n', runs{r,1}, runs{r,2}, runs{r,3}, S.ddd(i), S.M_2(i)/1e3); end
    C(end+1) = struct('fam', runs{r,1}, 'n', runs{r,2}, 'nl', runs{r,3}, 'th', S.ddd(1:c), 'M', S.M_2(1:c)/1e3, 'wall', local_wall(logtxt, runs{r,5})); %#ok<SAGROW>
    fprintf('%-6s n %2d n_l %2d: %d steps, M(4 deg) = %.1f MN.m, wall %s min\n', runs{r,1}, runs{r,2}, runs{r,3}, c, C(end).M(end), num2str(C(end).wall));
end
fclose(fid); fprintf('conv csv ok: %s\n', out);
% ---- table ----
tt = [0.5 1 2 4]; Mat = @(p, t) p.M(find(abs(p.th - t) < 1e-6, 1));
iref = find(strcmp({C.fam}, 'n') & [C.n] == nref & [C.nl] == nlref, 1); if isempty(iref), error('reference run n = %d / n_l = %d missing', nref, nlref); end
Pref = C(iref); tf = fopen(['conv' SUF '_table.txt'], 'w');
fprintf(tf, 'Tripod (Kim et al. 2014 case, runs%s, 18-step sweep 0.03-4 deg, azimuth 0): discretisation convergence of the moment M [MN.m]\n', SUF);
fprintf(tf, 'd%% = change relative to the reference n = %d / n_l = %d; max|d%%| = largest |change| over the 18 sweep steps; wall = queue wall time [min] at 2 concurrent MATLAB instances (minute resolution; blank if no log)\n', nref, nlref);
blocks = {'n', '(a) n strips per circumference, n_l = 25', 'n'; 'nl', '(b) n_l levels along the skirt, n = 40', 'n_l'; 'combo', '(c) combined n = n_l = 16 (tetrapod discretisation) vs the reference 40 / 25', 'n / n_l'};
for bk = 1:size(blocks, 1)
    sel = C(strcmp({C.fam}, blocks{bk,1})); if isempty(sel), continue; end
    fprintf(tf, '\n%s\n%7s |', blocks{bk,2}, blocks{bk,3}); for t = tt, fprintf(tf, ' M(%g)   d%%   |', t); end; fprintf(tf, ' max|d%%| | wall\n');
    for p = sel
        if strcmp(blocks{bk,1}, 'n'), lab = sprintf('%d', p.n); elseif strcmp(blocks{bk,1}, 'nl'), lab = sprintf('%d', p.nl); else, lab = sprintf('%d/%d', p.n, p.nl); end
        fprintf(tf, '%7s |', lab); for t = tt, m = Mat(p, t); fprintf(tf, ' %6.1f %6.2f |', m, (m/Mat(Pref, t) - 1)*100); end
        dall = (p.M./Pref.M - 1)*100; [mx, im] = max(abs(dall)); if isempty(p.wall), ws = ''; else, ws = sprintf('%g', p.wall); end
        fprintf(tf, ' %5.2f (%.2f deg) | %s\n', mx, p.th(im), ws);
    end
end
fclose(tf); type(['conv' SUF '_table.txt']);

function w = local_wall(txt, job)
% wall time [min] of a queue job from '<job> start HH:MM' and '<job> ok HH:MM' lines; [] if absent
w = [];
if isempty(txt), return; end
a = regexp(txt, ['\S*' job ' start (\d+):(\d+)'], 'tokens', 'once'); b = regexp(txt, ['\S*' job ' ok (\d+):(\d+)'], 'tokens', 'once');
if isempty(a) || isempty(b), return; end
w = mod((str2double(b{1})*60 + str2double(b{2})) - (str2double(a{1})*60 + str2double(a{2})), 24*60);
end
