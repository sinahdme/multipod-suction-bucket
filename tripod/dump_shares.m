% DUMP_SHARES  Per-bucket moment shares of the spring families (t-z, p-y, q-z tip, q-z lid, %) vs rotation, to
% shares_data<SUF>.csv (case, theta_deg, bucket, tz, py, qz_tip, qz_lid, M_tz_s, M_py_s, M_qztip_s, M_qzlid_s,
% tz_s, py_s, qz_tip_s, qz_lid_s) from the M_*_pct stores of the listed result files (case = run tag without the
% leading underscore). The tz..qz_lid shares (cols 4-7) are those of the script (family vector NORMS over their sum per
% bucket). Cols 8-11 are the signed family moments per bucket [MN.m] projected on the overturning axis
% (Mfam_b_signed_store, -dot(M_fam, a_ov); their sum over buckets and families is the total soil moment M_2). Cols 12-15
% are the SIGNED shares, 100 * M_fam_s / sum_fam(M_fam_s) per bucket (the bucket's signed moment M_b as denominator; a
% family acting in the driving sense has a negative share and the others then exceed 100 %; the shares are large where
% M_b passes through zero, e.g. the lifted bucket at ~0.1 deg). Cols 8-15 are NaN for result files without the signed
% store (ver40 runs). plot_shares_svg.js draws the signed shares when they are finite, otherwise cols 4-7.
% Also writes shares_signed_table<SUF>.txt: norm vs signed shares of buckets 1 and 2 at selected rotations, and the
% rotation at which the signed bucket moment changes sign.
% SUF selects the run set and the output name (default ''):
%   ''      _icr_uy25, _icr_uy65                       -> shares_data.csv (cols 8-15 NaN)
%   '_v41'  _fix_uy25_t0_v41, _fix_uy65_t0_v41         -> shares_data_v41.csv
if ~exist('SUF', 'var'), SUF = ''; end
if isempty(SUF), tags = {'_icr_uy25', '_icr_uy65'}; else, tags = {['_fix_uy25_t0' SUF], ['_fix_uy65_t0' SUF]}; end
out = ['shares_data' SUF '.csv']; fid = fopen(out, 'w');
fprintf(fid, 'case,theta_deg,bucket,tz,py,qz_tip,qz_lid,M_tz_s,M_py_s,M_qztip_s,M_qzlid_s,tz_s,py_s,qz_tip_s,qz_lid_s\n');
ft = fopen(['shares_signed_table' SUF '.txt'], 'w');
fprintf(ft, 'Per-bucket spring-family moment shares [%%]: norm-based (family vector norms / their sum, M_*_pct of the script) vs\n');
fprintf(ft, 'signed (family moment projected on the overturning axis / signed bucket moment M_b). Families: tz / py / tip / lid.\n');
sel = [0.03 0.1 0.5 1 2 4];   % rotations of the table
for r = 1:numel(tags)
    f = ['kim_validation_results' tags{r} '.mat']; if ~exist(f, 'file'), fprintf('missing %s\n', f); continue; end
    S = load(f, 'M_tz_pct', 'M_py_pct', 'M_qztip_pct', 'M_qzlid_pct', 'ddd', 'count', 'M_2');
    w = who('-file', f); c = S.count; Ms = nan(c, 3, 4);   % signed store: step x bucket x family (p-y, t-z, tip, lid), kN.m
    if ismember('Mfam_b_signed_store', w), T = load(f, 'Mfam_b_signed_store'); Ms = T.Mfam_b_signed_store(1:c,:,:); end
    Mb = sum(Ms, 3);                                       % signed bucket moment, kN.m (step x bucket)
    Ps = 100 * Ms ./ Mb;                                   % signed shares, % (step x bucket x family)
    for b = 1:3, for i = 1:c
        fprintf(fid, '%s,%.4f,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f\n', tags{r}(2:end), S.ddd(i), b, ...
            S.M_tz_pct(i,b), S.M_py_pct(i,b), S.M_qztip_pct(i,b), S.M_qzlid_pct(i,b), ...
            Ms(i,b,2)/1e3, Ms(i,b,1)/1e3, Ms(i,b,3)/1e3, Ms(i,b,4)/1e3, Ps(i,b,2), Ps(i,b,1), Ps(i,b,3), Ps(i,b,4));
    end; end
    k = c; fprintf('%s: %d steps; at %.2f deg norm shares tz/py/tip/lid [%%] b1 %.1f/%.1f/%.1f/%.1f, b2 %.1f/%.1f/%.1f/%.1f\n', tags{r}, c, S.ddd(k), ...
        S.M_tz_pct(k,1), S.M_py_pct(k,1), S.M_qztip_pct(k,1), S.M_qzlid_pct(k,1), S.M_tz_pct(k,2), S.M_py_pct(k,2), S.M_qztip_pct(k,2), S.M_qzlid_pct(k,2));
    if all(isfinite(Ms(:)))
        fprintf('  signed family moments at %.2f deg [MN.m] (py, tz, tip, lid): b1 %s; b2 %s; sum %.1f vs M_2 %.1f\n', S.ddd(k), ...
            mat2str(squeeze(Ms(k,1,:))'/1e3, 4), mat2str(squeeze(Ms(k,2,:))'/1e3, 4), sum(Ms(k,:,:), 'all')/1e3, S.M_2(k)/1e3);
        fprintf('  signed shares at %.2f deg [%%] (tz, py, tip, lid): b1 %s; b2 %s\n', S.ddd(k), ...
            mat2str(squeeze(Ps(k,1,[2 1 3 4]))', 4), mat2str(squeeze(Ps(k,2,[2 1 3 4]))', 4));
        M2 = S.M_2(1:c); M2 = M2(:);   % kN.m, column
        fprintf(ft, '\n%s (%d steps): sum of the signed family moments = M_2 to %.2g %% (max over steps)\n', tags{r}(2:end), c, ...
            100 * max(abs(sum(Ms(1:c,:,:), [2 3]) - M2) ./ abs(M2)));
        for b = [1 2]
            fprintf(ft, ' bucket %d   theta   M_b [MN.m] |   norm  tz/py/tip/lid   |  signed tz/py/tip/lid\n', b);
            for th = sel
                [~, i] = min(abs(S.ddd(1:c) - th)); if abs(S.ddd(i) - th) > 1e-6, continue; end
                fprintf(ft, '          %6.2f   %8.2f   | %5.1f %5.1f %4.1f %4.1f | %6.1f %6.1f %5.1f %5.1f\n', S.ddd(i), Mb(i,b)/1e3, ...
                    S.M_tz_pct(i,b), S.M_py_pct(i,b), S.M_qztip_pct(i,b), S.M_qzlid_pct(i,b), Ps(i,b,2), Ps(i,b,1), Ps(i,b,3), Ps(i,b,4));
            end
            j = find(Mb(1:c-1,b) .* Mb(2:c,b) < 0);   % sign changes of the bucket moment (log-linear interpolation)
            for q = j(:)'
                thz = 10^(log10(S.ddd(q)) + (0 - Mb(q,b)) / (Mb(q+1,b) - Mb(q,b)) * (log10(S.ddd(q+1)) - log10(S.ddd(q))));
                fprintf(ft, '          M_b changes sign between %.2f and %.2f deg (zero at ~%.3f deg)\n', S.ddd(q), S.ddd(q+1), thz);
            end
            % steps where a family acts in the driving sense (negative signed moment while M_b > 0, or vice versa)
            fam = {'py', 'tz', 'tip', 'lid'};
            for m = 1:4
                neg = find(Ps(1:c,b,m) < -0.05); if ~isempty(neg), fprintf(ft, '          %s share < 0 at theta = %s deg\n', fam{m}, mat2str(S.ddd(neg)')); end
            end
        end
    end
end
fclose(fid); fclose(ft); fprintf('shares csv ok: %s\n', out);
