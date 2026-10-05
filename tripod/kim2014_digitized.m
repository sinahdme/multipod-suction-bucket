function d = kim2014_digitized()
% KIM2014_DIGITIZED  Kim et al. (2014) T2 tripod centrifuge moment-rotation points (prototype scale).
% v2 (2026-10-04): d.exp is now read from the ORIGINAL paper, Kim et al. 2014, JGGE 140(5):04014008, Fig. 7 (T2, first
% loading branch), re-digitised from the embedded figure (calibrated on the tick marks, residual < 0.5 px; 1 px = 0.0194 deg
% x 0.845 MN.m) and checked independently at 30 points (kim2014_data/T2_fig7_independent_check.csv: no point off by more
% than 0.02 deg). The full curve is kim2014_data/kim2014_fig7_T2_virgin.csv (d.exp_curve). Kim et al. Fig. 10 shows a
% second T2 curve 3-9 % higher (kim2014_fig10_T2_monotonic.csv), the one replotted by Barari et al. (2023); Fig. 7 is used.
% The earlier points, read by eye from the rev_30 manuscript figure, are kept as d.exp_byeye (16-20 MN.m too low at
% 0.1-0.3 deg, 6.7 MN.m too low at 4 deg); they were used for all results up to ver46 (_v41 runs).
d.exp.deg = [0 0.1 0.2 0.3 0.4 0.5 0.6 0.8 1.0 1.2 1.5 2.0 2.5 3.0 3.5 4.0];
d.exp.M   = [0 36.0 61.1 76.1 82.7 87.6 93.3 100.8 107.7 108.9 115.9 126.4 135.8 146.1 154.1 163.4];   % MN.m, Kim et al. (2014) Fig. 7, T2
d.exp_byeye.deg = [0 0.1 0.2 0.3 0.4 0.5 0.6 0.8 1.0 1.2 1.5 2.0 2.5 3.0 3.5 4.0];
d.exp_byeye.M   = [0 19.5 41.5 59.5 75 84.5 92.5 102.5 109.5 115.5 122.5 131.5 139.5 147.5 152.5 156.5];   % MN.m, by eye (superseded)
f = fullfile(fileparts(mfilename('fullpath')), 'kim2014_data', 'kim2014_fig7_T2_virgin.csv');
if exist(f, 'file')
    t = readmatrix(f, 'NumHeaderLines', 2, 'Range', 'A:B'); t = t(all(isfinite(t), 2), :);
    d.exp_curve.deg = t(:, 1)'; d.exp_curve.M = t(:, 2)';
else
    d.exp_curve = d.exp;
end
d.exp_yield = struct('deg', 0.6, 'M', 93);   % yield point stated by Kim et al. (p.7), construction of Villalobos et al.
d.rev30.deg = [0 0.1 0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0 2.2 2.4 2.6 2.8 3.0 3.2 3.4 3.6 3.8 4.0];
d.rev30.M   = [0 59.5 77 92 103.5 113.5 121.5 127.5 134.5 139.5 142.5 145.5 149 151.5 152.5 154.5 155.5 156.5 158 158 160 160.5];
d.meta = 'exp: Kim et al. (2014) Fig. 7 T2, re-digitised from the original paper (2026-10-04); exp_byeye: by eye from CG Manuscript rev_30 Fig. 18 (superseded)';
end
