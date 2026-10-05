% DUMP_MONO_UY  Monopod (Wang et al. 2018 case, Table S2): mudline moment-rotation for t-z mobilisation displacements of
% 2.5 mm, 75 mm (0.5% D) and 150 mm (1% D), Fig. S2 of the Supplementary, from monopod_results_f_uy{2p5,75,150}.mat
% (MAINCODE runs mono_uy2p5, mono_uy75, mono_uy150 of run_paper_cases.m), together with the 100g centrifuge test and
% the FE curve of Wang et al. (2018) (wang2018_monopod_reference.csv), to mono_uy_curves.csv (case, theta_deg, M_MNm).
ref = fullfile(fileparts(mfilename('fullpath')), 'wang2018_monopod_reference.csv');
R = strtrim(fileread(ref)); R = regexprep(R, '\r', ''); R = strsplit(R, newline);
fid = fopen('mono_uy_curves.csv', 'w'); fprintf(fid, 'case,theta_deg,M_MNm\n'); fprintf(fid, '%s\n', R{2:end});
runs = {'uy2.5', '_f_uy2p5'; 'uy75', '_f_uy75'; 'uy150', '_f_uy150'};
for r = 1:size(runs, 1)
    S = load(['monopod_results' runs{r, 2} '.mat'], 'M_2', 'ddd', 'count');   % ddd [deg], M_2 [MN.m]
    for i = 1:S.count, fprintf(fid, '%s,%.4f,%.3f\n', runs{r, 1}, S.ddd(i), S.M_2(i)); end
    fprintf('%s: %d steps to %.2f deg, M = %.1f MN.m\n', runs{r, 1}, S.count, S.ddd(S.count), S.M_2(S.count));
end
fclose(fid); disp('mono_uy_curves.csv written');
