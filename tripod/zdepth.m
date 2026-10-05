function d = zdepth(zf)
% ZDEPTH  Depth below the mudline passed to coeffinder in the rotation loop.
% Default: abs(z) (published behaviour). With setappdata(0,'PY_MUDLINE',true)
% (RUN_CFG.SENS.py_mudline, v2 2026-09-29) nodes above the mudline get zero depth,
% so they carry no p-y resistance (P_R = 0) and no at-rest stress (sigma_0 = 0).
d = abs(zf);
if isappdata(0,'PY_MUDLINE') && getappdata(0,'PY_MUDLINE'), d = max(0,-zf); end
end
