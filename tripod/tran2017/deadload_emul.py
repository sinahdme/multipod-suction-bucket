# Emulation of the per-bucket vertical springs of the dead-load stage (tzcurve_noOCR, qzcurve2, qzcurve4 legacy)
import math, numpy as np
def bucket_F(dz, D, L, gam, phi, Dr, t=0.025, n=40, nl=25, nq=10, Zlid=0.001, lid_model='legacy', zG0=None):
    do=D; di=D-2*t; delta=2*phi/3
    h=L/nl; zb=(np.arange(nl)+0.5)*h        # body depth of ring centres
    zf=zb+dz                                # fixed-frame depth after settlement
    s=math.sin(math.radians(phi)); c=math.cos(math.radians(phi))
    K0nc=(math.sqrt(0.75)-s)/(2*c-1)
    f1=np.interp(min(max(delta,15),35),[15,20,25,30,35],[47.8,67.0,81.3,95.7,114.8])
    tin=np.minimum(K0nc*gam*zf*math.tan(math.radians(delta)),f1)
    tout=np.minimum((1-s)*gam*zb*math.tan(math.radians(delta)),f1)
    ratio=min(1,abs(dz*1e3)/2.5)
    Ff=ratio*(tin.sum()*h*math.pi*di + tout.sum()*h*math.pi*do)   # embed factor 1 (all below mudline)
    # tip
    Nq_t=np.interp(math.degrees(math.atan(2/3*math.tan(math.radians(phi)))),[15,20,25,30,35],[8,12,20,40,50])
    wD=dz/do
    qr=min(1,np.interp(wD,[0,0.002,0.013,0.042,0.073,0.1,1],[0,0.25,0.5,0.75,0.9,1,1]))
    Ft=Nq_t*gam*L*math.pi*di*t*qr
    # lid
    rp=di/2+t/2
    nu=(1-s)/(2-s)
    z0=Zlid if zG0 is None else zG0
    pa=100
    Nq=math.tan(math.radians(45+phi/2))**2*math.exp(math.pi*math.tan(math.radians(phi)))
    Ng=1.5*(Nq-1)*math.tan(math.radians(phi))
    qu=0.5*gam*di*Ng*0.5+gam*Zlid*Nq
    if lid_model=='legacy':
        G0=400*pa*math.exp(0.7*Dr)*(gam*(1-s)*z0/pa)**0.5
        Ke=8*G0/(1-nu)/math.pi/di
        q = qu if Ke*dz>=qu else Ke*dz/(1+Ke*dz/qu)
    Fl=q*math.pi*rp**2
    return Ff+Ft+Fl, Ff, Ft, Fl, Ke, qu
def solve(V, D, L, gam, phi, Dr):
    target=V/3
    lo,hi=0.0,0.5*D
    if bucket_F(hi,D,L,gam,phi,Dr)[0]<target: return float('nan'),None
    for _ in range(80):
        mid=0.5*(lo+hi)
        if bucket_F(mid,D,L,gam,phi,Dr)[0]<target: lo=mid
        else: hi=mid
    return hi, bucket_F(hi,D,L,gam,phi,Dr)
cases=[(6,6),(9,6),(9,9),(12,6),(12,12),(15,6)]
for sand,gam,phi,Dr in [('med',0.9*9.81,35,0.5),('den',1.0*9.81,38,0.8)]:
    for V in [5000,10000,20000]:
        for D,L in cases:
            dz,F=solve(V,D,L,gam,phi,Dr)
            Ffmax=bucket_F(1.0,D,L,gam,phi,Dr)[1]
            print(f'{sand} V{V/1000:.0f} D{D} L{L}: V/3={V/3:7.0f} kN, friction cap {Ffmax:7.0f}, dz = {dz*1000:8.1f} mm, lid share {F[3]:7.0f} kN, Ke={F[4]:.0f} kPa/m, qu={F[5]:.0f} kPa')
