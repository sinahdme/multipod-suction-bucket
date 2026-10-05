function make_figure_data(groups)
% MAKE_FIGURE_DATA  Writes the data of the figures and tables of the paper (CSV/TXT) from the result files written by
% run_paper_cases.m. The files are written next to the results (results/<model>/); the same files, computed from the
% final runs of the manuscript, are in paper_results/ for comparison.
%
%   make_figure_data                        all MATLAB models ('tripod', 'tetrapod', 'monopod')
%   make_figure_data({'tripod'})            one or more groups
%
% The Tran et al. (2017) cases (Table S3, Fig. S10) are post-processed in Python, see README.md:
%   python tripod/tran2017/tran_capacity.py      -> results/tran2017/tran_capacity.csv   (tangent intersection)
%   python tripod/tran2017/make_table_s3.py      -> results/tran2017/table_s3.csv, table_s3_stats.csv
%   python tripod/tran2017/plot_fig_s10.py       -> results/tran2017/Fig_S10.png / .pdf

ROOT = fileparts(mfilename('fullpath'));
if nargin == 0, groups = {'tripod', 'tetrapod', 'monopod'}; end
if ischar(groups), groups = {groups}; end
% dump script, workspace variables it reads, figures/tables of the paper it serves
J.tripod = {
    'dump_mtheta_uy',  struct('SUF', '_v47'), 'Fig. 5 (mtheta_uy_kim_v47.csv, with the Kim et al. test curve)'
    'dump_icr_uy',     struct('SUF', '_v47'), 'Fig. 6 (icr_uy_data_v47.csv, icr_uy_table_v47.txt)'
    'dump_shares',     struct('SUF', '_v47'), 'Fig. 7 (shares_data_v47.csv, shares_signed_table_v47.txt)'
    'dump_polar_v2',   struct('SUF', '_v47'), 'Fig. 8 (polar_v2_data_v47.csv, polar_v2_table_v47.txt)'
    'dump_conv',       struct('SUF', '_v47'), 'Fig. S1 (conv_v47.csv, conv_v47_table.txt)'
    'dump_py_depth',   struct('SUF', '_v47'), 'Fig. S11 (py_depth_uy_data_v47.csv)'
    'dump_fig15',      struct('SUF', '_v47'), 'Fig. S12 (fig15_nodes_*_v47.csv, fig15_meta_*_v47.csv)'
    'dump_tz_sides',   struct('SUF', '_v47'), 'Fig. S13 (tz_sides_data_v47.csv)'
    'dump_fig16',      struct('SUF', '_v47'), 'Fig. S14 (fig16_nodes_*_v47.csv)'};
J.tetrapod = {
    'dump_mtheta_baseline', struct('SUF', '_v47'), 'Fig. 9, baseline (mtheta_baseline_barari_v47.csv, with the Barari et al. FE curves)'
    'dump_mtheta_uy',       struct('SUF', '_v47'), 'Fig. 9, u_y variants (mtheta_uy_barari_v47.csv)'
    'dump_icr_tetra_uy',    struct('SUF', '_v47'), 'Figs. 10, 11 (icr_tetrapod_uy_data_v47.csv, icr_tetrapod_uy_table_v47.txt)'
    'dump_spacing',         struct('SUF', '_v47'), 'Fig. S9 (spacing_v47.csv, spacing_v47.txt)'
    'dump_vbuckets',        struct('SUF', '_v47'), 'Section 3.1.3, bucket vertical forces (vbuckets_v47.csv)'
    'dump_diag_v41',        struct('SUF', '_v47'), 'Section 3.1.3, per-bucket moment shares (diag_per_bucket_v47.txt)'};
J.monopod = {
    'dump_mono_uy',     struct(),               'Fig. S2 (mono_uy_curves.csv, with the Wang et al. test and FE curves)'
    'dump_shares_mono', struct('TAG', 'f_uy2p5'), 'Fig. S3(a) (shares_mono_f_uy2p5.csv)'
    'dump_shares_mono', struct('TAG', 'f_base'),  'Fig. S3(b) (shares_mono_f_base.csv)'
    'dump_supp_mono',   struct('TAG', 't04g'),    'Figs. S4-S8 (mono_py_depth_t04g.csv, mono_nodes_4deg_t04g.csv, mono_tz_sides_t04g.csv, mono_icr_t04g.csv)'};
all_dirs = {fullfile(ROOT, 'monopod'), fullfile(ROOT, 'tripod'), fullfile(ROOT, 'tetrapod'), fullfile(ROOT, 'tripod', 'tran2017')};
here = pwd; status = {};
for g = 1:numel(groups)
    m = groups{g}; res = fullfile(ROOT, 'results', m);
    if ~isfield(J, m), error('unknown group %s', m); end
    if ~exist(res, 'dir'), status{end+1} = sprintf('%-9s no results folder %s (run run_paper_cases first)', m, res); continue; end %#ok<AGROW>
    p = path; for d = all_dirs, if contains([pathsep p pathsep], [pathsep d{1} pathsep]), rmpath(d{1}); end, end
    addpath(fullfile(ROOT, m));
    for k = 1:size(J.(m), 1)
        fprintf('\n==== %s / %s: %s\n', m, J.(m){k, 1}, J.(m){k, 3});
        try
            cd(res); run_dump(J.(m){k, 1}, J.(m){k, 2}); cd(here);
            status{end+1} = sprintf('%-9s %-22s ok      %s', m, J.(m){k, 1}, J.(m){k, 3}); %#ok<AGROW>
        catch ME
            cd(here); status{end+1} = sprintf('%-9s %-22s FAILED  %s', m, J.(m){k, 1}, ME.message); %#ok<AGROW>
        end
    end
    rmpath(fullfile(ROOT, m));
end
fprintf('\nSummary\n'); fprintf('%s\n', status{:});
end

function run_dump(NAME__, VARS__)
% Runs one dump script in its own workspace with the variables it reads (SUF or TAG).
f__ = fieldnames(VARS__);
for i__ = 1:numel(f__), eval([f__{i__} ' = VARS__.(f__{i__});']); end
clear f__ i__
eval(NAME__);
end
