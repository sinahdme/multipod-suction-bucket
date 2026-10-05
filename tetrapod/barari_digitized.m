function d = barari_digitized()
% BARARI_DIGITIZED  Digitized M-theta curves from Barari et al. (2023),
% Int J Numer Anal Methods Geomech. 47:2872-2898, DOI 10.1002/nag.3605.
%
% Source figures (raster JPEGs extracted from the journal PDF):
%   Fig. 20(B): tetrapod, L/D = 1.0, baseline spacing (S/D = 3), loaded at
%               33 m above RP, two load directions theta = 0 and 45 deg.
%               ANGLE CONVENTION (their Fig. 20(A)): buckets at the corners
%               of an axis-aligned square (azimuths 45/135/225/315 from the
%               group centre) and theta measured from +x:
%                 theta = 0  -> load BETWEEN buckets  (their CRITICAL dir.)
%                 theta = 45 -> load TOWARD a bucket  (their stronger dir.)
%               This is the SAME layout and convention as
%               FOUR_POD_BARARI_VALIDATION.m (tilt_angle 0 / 45).
%   Fig. 23 (right): tetrapod M-theta family over S/D at L/D = 1.00
%               (S/D = 2.5, 3.0, 4.0 digitized here); left: tripod S/D = 3.
%
% Units: theta [deg], M [kN*m] (their axes are x1e5 kNm).
%
% ACCURACY: digitized by eye against the 1-deg x 0.5e5-kNm grid of the
% published raster; estimated error +/-3-5% (worst near the sharp knees).
% For the final publication overlay, re-digitize with WebPlotDigitizer and
% replace these arrays. Internal consistency check: Fig. 23 S/D=3 endpoint
% (2.63e5) vs Fig. 20 theta=0 endpoint (2.56e5) agree within ~3%.

% ---- Fig. 20(B): tetrapod S/D = 3, two load directions ----
d.fig20.theta0.deg = [0    0.20 0.35 0.45 0.55 0.70 1.0  1.5  2.0  2.5  3.0  3.5  4.0  4.5  5.1];
d.fig20.theta0.M   = [0.10 0.75 1.30 1.50 1.57 1.60 1.68 1.85 2.02 2.13 2.27 2.35 2.42 2.49 2.56]*1e5;

d.fig20.theta45.deg = [0    0.20 0.45 0.70 1.0  1.25 1.5  2.0  2.5  3.0  3.5  4.0  4.5  5.1];
d.fig20.theta45.M   = [0.12 0.65 1.30 1.70 2.10 2.35 2.43 2.55 2.63 2.72 2.80 2.88 2.96 3.06]*1e5;

% ---- Fig. 23 (right): tetrapod family, L/D = 1.00 (load dir. = critical 0 deg) ----
d.fig23.tetra_SD25.deg = [0.5  1.0  2.0  3.0  4.0  5.1];
d.fig23.tetra_SD25.M   = [1.30 1.50 1.75 1.95 2.10 2.30]*1e5;

d.fig23.tetra_SD30.deg = [0.5  1.0  1.5  2.0  2.5  3.0  3.5  4.0  4.5  5.1];
d.fig23.tetra_SD30.M   = [1.38 1.72 1.90 2.05 2.18 2.30 2.40 2.48 2.55 2.63]*1e5;

d.fig23.tetra_SD40.deg = [0.5  1.0  2.0  3.0  4.0  5.1];
d.fig23.tetra_SD40.M   = [2.00 2.40 2.70 2.90 3.05 3.19]*1e5;

% ---- Fig. 23 (left): tripod S/D = 3.00, L/D = 1.00 ----
d.fig23.tri_SD30.deg = [0.3  0.5  1.0  2.0  3.0  4.0  5.15];
d.fig23.tri_SD30.M   = [0.75 0.85 1.05 1.28 1.44 1.55 1.64]*1e5;

% metadata
d.meta.units   = 'theta [deg], M [kN*m]';
d.meta.source  = 'Barari et al. (2023) IJNAMG 47:2872-2898, Figs. 20(B) and 23';
d.meta.method  = 'manual digitization from extracted raster, +/-3-5%';
d.meta.soil    = 'Saemangeum silty sand, Dr = 75%, HSsmall (their Table 3)';
d.meta.spacing = 'S = centre-of-group to bucket-centre (circumradius); S/D = 3 -> S = 19.5 m';
end
