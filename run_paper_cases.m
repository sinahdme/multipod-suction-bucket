function run_paper_cases(sel)
% RUN_PAPER_CASES  Runs the analyses of the paper (main text and Supplementary Material) with the exact settings used.
%
%   run_paper_cases                 lists the cases (id, model, figures/tables, result file)
%   run_paper_cases('all')          runs every case (about 2.3 h; run times per group in README.md)
%   run_paper_cases('tripod')       runs one group: 'tripod', 'tetrapod', 'monopod' or 'tran2017'
%   run_paper_cases({'tri_uy25_t0', 'tet_base_d0'})   runs the listed cases
%
% Results are written to results/<model>/ (results/tran2017/<case>/ for the Tran et al. (2017) cases), with the
% file names used by the post-processing (make_figure_data.m). The suffix _v47 of the result tags marks the final run
% set of the manuscript. Each case runs in its own function workspace; only the code folder of its model is on the
% path while it runs, because the three models share function names with different content.
%
% Requirements: MATLAB (developed and run with R2024b; no toolbox is required).

ROOT = fileparts(mfilename('fullpath'));
C = paper_cases();
if nargin == 0
    fprintf('%-24s %-9s %-34s %s\n', 'id', 'model', 'used in', 'result file');
    for k = 1:numel(C), fprintf('%-24s %-9s %-34s %s\n', C(k).id, C(k).model, C(k).used_in, result_file(C(k))); end
    fprintf('\n%d cases. Run with run_paper_cases(''all''), a group name or a cell array of ids.\n', numel(C));
    return
end
if ischar(sel) || isstring(sel)
    sel = char(sel);
    if strcmp(sel, 'all'), pick = 1:numel(C);
    elseif any(strcmp(sel, {'tripod', 'tetrapod', 'monopod', 'tran2017'})), pick = find(strcmp({C.model}, sel));
    else, pick = find(strcmp({C.id}, sel));
    end
else
    pick = zeros(1, numel(sel));
    for k = 1:numel(sel), j = find(strcmp({C.id}, sel{k})); if isempty(j), error('unknown case id: %s', sel{k}); end; pick(k) = j; end
end
if isempty(pick), error('no case selected (see run_paper_cases without arguments)'); end

code = struct('monopod', {{fullfile(ROOT, 'monopod')}}, 'tripod', {{fullfile(ROOT, 'tripod')}}, ...
              'tetrapod', {{fullfile(ROOT, 'tetrapod')}}, 'tran2017', {{fullfile(ROOT, 'tripod'), fullfile(ROOT, 'tripod', 'tran2017')}});
all_dirs = [code.monopod, code.tripod, code.tetrapod, code.tran2017(2)];
here = pwd; status = cell(numel(pick), 1);
for k = 1:numel(pick)
    c = C(pick(k));
    out = fullfile(ROOT, 'results', c.model); if strcmp(c.model, 'tran2017'), out = fullfile(out, c.id); end
    if ~exist(out, 'dir'), mkdir(out); end
    p = path; for d = all_dirs, if contains([pathsep p pathsep], [pathsep d{1} pathsep]), rmpath(d{1}); end, end
    addpath(code.(c.model){:});
    fprintf('\n==== [%d/%d] %s (%s) -> %s\n', k, numel(pick), c.id, c.script, out); t0 = tic;
    try
        cd(out); run_in_own_workspace(c.cfg, c.script); cd(here);
        status{k} = sprintf('%-24s ok      %6.1f min', c.id, toc(t0)/60);
    catch ME
        cd(here); status{k} = sprintf('%-24s FAILED  %s', c.id, ME.message);
    end
    rmpath(code.(c.model){:});
    fprintf('%s\n', status{k});
end
fprintf('\nSummary\n'); fprintf('%s\n', status{:});
end

function run_in_own_workspace(RUN_CFG, SCRIPT__) %#ok<INUSL>
% The model scripts read RUN_CFG from the calling workspace and start with clearvars -except RUN_CFG.
eval(SCRIPT__);
end

function f = result_file(c)
switch c.model
    case 'tripod',   f = ['tripod/kim_validation_results' c.cfg.OUT_TAG '.mat'];
    case 'tetrapod', f = ['tetrapod/barari_validation_results' c.cfg.OUT_TAG '.mat'];
    case 'monopod',  f = ['monopod/monopod_results' c.cfg.OUT_TAG '.mat'];
    case 'tran2017', f = ['tran2017/' c.id '/tran_tripod_results' c.cfg.OUT_TAG '.mat'];
end
end

function C = paper_cases()
C = struct('id', {}, 'model', {}, 'script', {}, 'used_in', {}, 'cfg', {});
add = @(C, id, model, script, used, cfg) [C, struct('id', id, 'model', model, 'script', script, 'used_in', used, 'cfg', cfg)];

% ---------------- Symmetric tripod, centrifuge test T2 of Kim et al. (2014): Section 3.1.1-3.1.2, Supplementary S2, S7
% Pull-out bound = the model's own drained pull-out capacity at installation (SENS.tension_cap_install), signed moment,
% p-y mudline cut-off and k_v in series (FIX_PROFILE 'pullout_kv'); no group interaction; load height 33.0 m; 18 steps.
dd_tri = [0.03 0.05 0.1 0.15 0.2 0.3 0.4 0.5 0.6 0.75 1 1.25 1.5 2 2.5 3 3.5 4]*pi/180;
S = 'THREE_POD_KIM2014_VALIDATION_LD123';
C = add(C, 'tri_uy25_t0', 'tripod', S, 'Figs. 5-8, S1 (n=40, nl=25), S11-S14', struct('OUT_TAG','_fix_uy25_t0_v47','FIX_PROFILE','pullout_kv','tilt_dir',0,'MAKE_FIGS',false,'FAST_SEARCH',true,'GRP',struct('enable',false),'eccentricity',33.0,'dd_vec',dd_tri,'SENS',struct('tension_cap_install',true)));
C = add(C, 'tri_uy33_t0', 'tripod', S, 'Figs. 5, 6', struct('OUT_TAG','_fix_uy33_t0_v47','FIX_PROFILE','pullout_kv','tilt_dir',0,'MAKE_FIGS',false,'FAST_SEARCH',true,'GRP',struct('enable',false),'eccentricity',33.0,'dd_vec',dd_tri,'SENS',struct('tension_cap_install',true,'tz_uy_mm',33)));
C = add(C, 'tri_uy65_t0', 'tripod', S, 'Figs. 5, 6', struct('OUT_TAG','_fix_uy65_t0_v47','FIX_PROFILE','pullout_kv','tilt_dir',0,'MAKE_FIGS',false,'FAST_SEARCH',true,'GRP',struct('enable',false),'eccentricity',33.0,'dd_vec',dd_tri,'SENS',struct('tension_cap_install',true,'tz_uy_mm',65)));
for a = [15 30 45 60 180]
    C = add(C, sprintf('tri_tilt%d', a), 'tripod', S, 'Fig. 8', struct('OUT_TAG',sprintf('_fix_tilt%d_v47', a),'FIX_PROFILE','pullout_kv','tilt_dir',a,'MAKE_FIGS',false,'FAST_SEARCH',true,'GRP',struct('enable',false),'eccentricity',33.0,'dd_vec',dd_tri,'SENS',struct('tension_cap_install',true)));
end
for g = [8 25; 16 25; 24 25; 32 25; 40 5; 40 10; 40 15; 40 20; 16 16]'
    C = add(C, sprintf('tri_conv_n%d_nl%d', g(1), g(2)), 'tripod', S, 'Fig. S1', struct('OUT_TAG',sprintf('_fix_conv_n%d_nl%d_v47', g(1), g(2)),'FIX_PROFILE','pullout_kv','tilt_dir',0,'MAKE_FIGS',false,'FAST_SEARCH',true,'GRP',struct('enable',false),'eccentricity',33.0,'dd_vec',dd_tri,'n',g(1),'n_l',g(2),'SENS',struct('tension_cap_install',true)));
end

% ---------------- Symmetric tetrapod, 3D FE of Barari et al. (2023): Section 3.1.3, 3.2, Supplementary S4
% V = 1110 kN (inferred), pull-out bound 2640 kN per bucket, FIX_PROFILE 'pullout_kv', no group interaction.
dd_tet41 = sort([0.05:0.05:0.5, 0.6:0.1:2.0, 0.75, 1.25, 2.25:0.25:5.5])*pi/180;   % 41 steps (baseline)
dd_tet11 = [0.05 0.2 0.5 0.75 1 1.25 1.5 2 3 4 5]*pi/180;                            % 11 steps (u_y and spacing variants)
S = 'FOUR_POD_BARARI_VALIDATION';
for d = [0 45]
    used = 'Figs. 9, 10; Sec. 3.1.3'; if d == 0, used = 'Figs. 9, 10, S9 (S/D=3); Sec. 3.1.3'; end
    C = add(C, sprintf('tet_base_d%d', d), 'tetrapod', S, used, struct('OUT_TAG',sprintf('_fix_V1110_d%d_v47', d),'FIX_PROFILE','pullout_kv','Deadload',1110,'tilt_directions',d,'LID_G0_MODE','legacy','MAKE_FIGS',false,'FAST_SEARCH',true,'GRP',struct('enable',false),'dd_vec',dd_tet41,'SENS',struct('tension_cap_kN',2640)));
end
for u = [33 65], for d = [0 45]
    used = 'Fig. 9 (also read by dump_icr_tetra_uy)'; if u == 65, used = 'Figs. 9, 11'; end
    C = add(C, sprintf('tet_uy%d_d%d', u, d), 'tetrapod', S, used, struct('OUT_TAG',sprintf('_fix_uy%d_V1110_d%d_v47', u, d),'FIX_PROFILE','pullout_kv','Deadload',1110,'tilt_directions',d,'LID_G0_MODE','legacy','MAKE_FIGS',false,'FAST_SEARCH',true,'GRP',struct('enable',false),'dd_vec',dd_tet11,'SENS',struct('tension_cap_kN',2640,'tz_uy_mm',u)));
end, end
C = add(C, 'tet_sd25_d0', 'tetrapod', S, 'Fig. S9 (S/D=2.5)', struct('OUT_TAG','_fix_sd25_V1110_d0_v47','FIX_PROFILE','pullout_kv','Deadload',1110,'tilt_directions',0,'LID_G0_MODE','legacy','MAKE_FIGS',false,'FAST_SEARCH',true,'GRP',struct('enable',false),'dd_vec',dd_tet11,'S_circ',16.25,'SENS',struct('tension_cap_kN',2640)));
C = add(C, 'tet_sd40_d0', 'tetrapod', S, 'Fig. S9 (S/D=4.0)', struct('OUT_TAG','_fix_sd40_V1110_d0_v47','FIX_PROFILE','pullout_kv','Deadload',1110,'tilt_directions',0,'LID_G0_MODE','legacy','MAKE_FIGS',false,'FAST_SEARCH',true,'GRP',struct('enable',false),'dd_vec',dd_tet11,'S_circ',26,'SENS',struct('tension_cap_kN',2640)));

% ---------------- Monopod, 100g centrifuge test of Wang et al. (2018): Supplementary S3 (single-bucket code)
dd_mono = [0.001 0.005 0.01 0.02 0.05 0.1 0.15 0.2 0.25 0.3 0.4 0.5 0.6 0.75 1 1.25 1.5 2 2.5 3 3.5 4]*pi/180;
S = 'MAINCODE';
C = add(C, 'mono_uy2p5', 'monopod', S, 'Figs. S2, S3(a)', struct('dd_vec',dd_mono,'MAKE_FIGS',false,'OUT_TAG','_f_uy2p5','thickness',0.4,'gamma',14.8,'FAST_SEARCH',true,'tz_uy_mm',2.5));
C = add(C, 'mono_uy75',  'monopod', S, 'Fig. S2', struct('dd_vec',dd_mono,'MAKE_FIGS',false,'OUT_TAG','_f_uy75','thickness',0.4,'gamma',14.8,'tz_uy_mm',75,'FAST_SEARCH',true));
C = add(C, 'mono_uy150', 'monopod', S, 'Fig. S2', struct('dd_vec',dd_mono,'MAKE_FIGS',false,'OUT_TAG','_f_uy150','thickness',0.4,'gamma',14.8,'tz_uy_mm',150,'FAST_SEARCH',true));
C = add(C, 'mono_skirt01', 'monopod', S, 'Fig. S3(b)', struct('dd_vec',dd_mono,'MAKE_FIGS',false,'OUT_TAG','_f_base','FAST_SEARCH',true,'tz_uy_mm',2.5));
C = add(C, 'mono_t04g',  'monopod', S, 'Figs. S4-S8', struct('dd_vec',dd_mono,'MAKE_FIGS',false,'OUT_TAG','_t04g','thickness',0.4,'gamma',14.8));

% ---------------- Tripods of Tran et al. (2017), Table 6 (S/D = 3): Supplementary S6, Table S3, Fig. S10
% The 23 cases with an estimated dead-load settlement of 0.1 m or less (deadload_emul.py). TR_den_V5_D9_L9 was run
% with the default iteration limits of the script (ECC_MAX_INNER 3000, STEP_TMAX 1200 s), the others with 1000 / 300 s.
dd_tran = [0.01 0.02 0.03 0.05 0.075 0.1 0.15 0.2 0.3 0.4 0.5 0.6 0.75 1 1.25 1.5 1.75 2 2.5 3 3.5 4]*pi/180;
TR = {'medium',5,6,6; 'medium',5,9,6; 'medium',5,9,9; 'medium',5,12,6; 'medium',5,12,12; 'medium',5,15,6; ...
      'medium',10,9,9; 'medium',10,12,6; 'medium',10,12,12; 'medium',10,15,6; 'medium',20,12,12; ...
      'dense',5,6,6; 'dense',5,9,6; 'dense',5,9,9; 'dense',5,12,6; 'dense',5,12,12; 'dense',5,15,6; ...
      'dense',10,9,6; 'dense',10,9,9; 'dense',10,12,6; 'dense',10,12,12; 'dense',10,15,6; 'dense',20,12,12};
for r = 1:size(TR, 1)
    id = sprintf('TR_%s_V%d_D%d_L%d', TR{r,1}(1:3), TR{r,2}, TR{r,3}, TR{r,4});
    cfg = struct('TRAN_SAND',TR{r,1},'D',TR{r,3},'L',TR{r,4},'V',1000*TR{r,2},'OUT_TAG',['_' id],'FIX_PROFILE','pullout_kv','TZ_LAW','noOCR','PY_LAW','knudsen','tilt_dir',0,'MAKE_FIGS',false,'FAST_SEARCH',true,'ECC_SEARCH','force','GRP',struct('enable',false),'dd_vec',dd_tran,'ECC_MAX_INNER',1000,'STEP_TMAX',300,'SENS',struct('tension_cap_install',true));
    if strcmp(id, 'TR_den_V5_D9_L9'), cfg = rmfield(cfg, {'ECC_MAX_INNER', 'STEP_TMAX'}); end
    C = add(C, id, 'tran2017', 'THREE_POD_TRAN2017_CASES', 'Table S3, Fig. S10', cfg);
end
end
