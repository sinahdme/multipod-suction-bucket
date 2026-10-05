% DUMP_SUPP_MONO  Monopod (Wang et al. 2018 case): data for the Supplementary figures S4-S8 from a MAINCODE sweep result
% (monopod_results_<TAG>.mat with the v2 per-step stores). Set TAG before calling (default 'wang_sweep').
%   mono_nodes_4deg_<TAG>.csv : node,x,y,z,Fpy_kN,Ftz_tot,Ftz_out,Ftz_in at the last step
%   mono_py_depth_<TAG>.csv   : theta_deg,z_over_L,Fpy_norm  (sum over the n springs of a layer / (gamma D^3))
%   mono_tz_sides_<TAG>.csv   : theta_deg,out_right,in_right,in_left,out_left  (F_tz / gamma D^3)
%   mono_icr_<TAG>.csv        : theta_deg,QX_over_D,QZ_over_L,M_MNm
if ~exist('TAG', 'var'), TAG = 'wang_sweep'; end
S = load(['monopod_results_' TAG '.mat']);
c = S.count; n = S.n; nl = S.n_l; g = S.gamma; D = S.do_b; L = S.l_b;
if isfield(S, 'anim_s_fixed')
  fid = fopen(['mono_nodes_4deg_' TAG '.csv'], 'w'); fprintf(fid, 'node,x,y,z,Fpy_kN,Ftz_tot,Ftz_out,Ftz_in\n');
  P = S.anim_s_fixed{c}; Fp = sqrt(S.anim_KKx{c}(:)'.^2 + S.anim_KKy{c}(:)'.^2); Fo = S.anim_KKz_out{c}(:)'; Fi = S.anim_KKz_in{c}(:)';
  for k = 1:numel(Fp), fprintf(fid, '%d,%.5f,%.5f,%.5f,%.6f,%.6f,%.6f,%.6f\n', k, P(1,k), P(2,k), P(3,k), Fp(k), Fo(k)+Fi(k), Fo(k), Fi(k)); end
  fclose(fid);
else
  Fp = 0; Fo = 0; Fi = 0; disp('no per-step node stores in this result (run made before the v2 stores) - S5/S7 data skipped');
end
fid = fopen(['mono_py_depth_' TAG '.csv'], 'w'); fprintf(fid, 'theta_deg,z_over_L,Fpy_norm\n'); zc = ((1:nl) - 0.5) * L / nl;
for i = 1:c, m = reshape(S.KKx_store(i,:), n, nl); f = sum(m, 1) / (g * D^3); for j = 1:nl, fprintf(fid, '%.4f,%.5f,%.6f\n', S.ddd(i), -zc(j)/L, f(j)); end; end
fclose(fid);
fid = fopen(['mono_tz_sides_' TAG '.csv'], 'w'); fprintf(fid, 'theta_deg,out_right,in_right,in_left,out_left\n');
for i = 1:c, fprintf(fid, '%.4f,%.6f,%.6f,%.6f,%.6f\n', S.ddd(i), S.tz_right_out_store(i), S.tz_right_in_store(i), S.tz_left_in_store(i), S.tz_left_out_store(i)); end
fclose(fid);
fid = fopen(['mono_icr_' TAG '.csv'], 'w'); fprintf(fid, 'theta_deg,QX_over_D,QZ_over_L,M_MNm\n');
for i = 1:c, fprintf(fid, '%.4f,%.5f,%.5f,%.4f\n', S.ddd(i), S.CENTE_OF_ROTATION(1,i)/D, S.CENTE_OF_ROTATION(3,i)/L, S.M_2(i)); end
fclose(fid);
fprintf('TAG %s: %d steps to %.2f deg, n=%d nl=%d, M(4)=%.1f MNm, |Fpy|max=%.1f kN, Ftz range %.1f..%.1f kN\n', TAG, c, S.ddd(c), n, nl, S.M_2(c), max(Fp), min(Fo+Fi), max(Fo+Fi)); disp('supp mono csv ok');
