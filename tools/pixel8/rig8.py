# procedural limbs for the 8-bit Code Bro: joint angles -> pixel limbs with a 1px outline
import math
from PIL import Image
exec(open('bro.py').read().split('def show')[0])
KC=P['K']
def seg_mask(pts,w,W=40,H=40):
    m=set()
    for (x0,y0),(x1,y1) in zip(pts,pts[1:]):
        dx,dy=x1-x0,y1-y0;L2=dx*dx+dy*dy or 1
        for y in range(H):
            for x in range(W):
                px,py=x+.5,y+.5;t=max(0,min(1,((px-x0)*dx+(py-y0)*dy)/L2))
                if (px-x0-t*dx)**2+(py-y0-t*dy)**2<=(w/2)**2: m.add((x,y))
    return m
def draw_mask(im,m,col,hi=None,lo=None):
    W,H=im.size
    for (x,y) in m:
        c=col
        if lo and (x+1,y) not in m: c=lo
        if hi and (x-1,y) not in m: c=hi
        if 0<=x<W and 0<=y<H: im.putpixel((x,y),c+(255,))
    for (x,y) in m:
        for nx,ny in((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
            if (nx,ny) not in m and 0<=nx<W and 0<=ny<H: im.putpixel((nx,ny),KC+(255,))
def pt(o,a,l): return (o[0]+l*math.sin(math.radians(a)),o[1]+l*math.cos(math.radians(a)))
GEO=dict(hip=(15.5,24.5),sb=(18,17.5),sf=(14.5,17.5),torso=(9,15),head=(10,3),leg=(5.5,5.0,4.2),arm=(4.6,4.2,3.6),fist=3.4)
def leg(im,hip,thigh,knee,front,lift=0):
    L1,L2,w=GEO['leg']
    k=pt(hip,thigh,L1);an=pt(k,thigh-knee,L2)
    m=seg_mask([hip,k,an],w,*im.size)
    draw_mask(im,m,P['B'] if front else P['b'],P['n'] if front else None,P['b'] if front else None)
    # shoe: flat-ish, toes forward, tilts with the shin when lifted
    tilt=max(-1,min(1,round((thigh-knee)/30)))
    sm=set()
    ax,ay=int(an[0]),int(an[1])
    for i in range(-2,5):
        for j in range(0,2):
            sm.add((ax+i,ay+j+(1 if i>=2 and tilt<0 else 0)-(1 if i>=3 and tilt>0 else 0)))
    draw_mask(im,sm,P['W'] if front else P['w'],None,None)
def arm(im,sh,up,fore,front,fist=True):
    L1,L2,w=GEO['arm']
    e=pt(sh,up,L1);h=pt(e,up+fore,L2)
    m=seg_mask([sh,e,h],w,*im.size)
    draw_mask(im,m,P['R'] if front else P['r'],P['Q'] if front else None,None)
    hm=seg_mask([h,h],GEO['fist'],*im.size)
    draw_mask(im,hm,P['S'] if front else P['s'])
def paste(im,g,x,y,alt=None):
    for j,r in enumerate(g):
        for i,c in enumerate(r):
            if c in P: im.putpixel((x+i,y+j),P[c]+(255,))
def pose(lb,lf,ab,af,bob=0,lean=0,W=36,H=38):
    """lb/lf: (thigh,knee) back/front leg; ab/af: (upper,fore) arms; angles in degrees, + = forward"""
    im=Image.new('RGBA',(W,H),(0,0,0,0))
    g=GEO;hx,hy=g['hip'];hip=(hx+lean*0.5,hy+bob)
    arm(im,(g['sb'][0]+lean,g['sb'][1]+bob),*ab,False)
    leg(im,(hip[0]-1,hip[1]),*lb,False)
    leg(im,(hip[0]+1,hip[1]),*lf,True)
    paste(im,TORSO,g['torso'][0]+lean,g['torso'][1]+bob); paste(im,HEAD,g['head'][0]+lean,g['head'][1]+bob)
    arm(im,(g['sf'][0]+lean,g['sf'][1]+bob),*af,True)
    return im
# walk: 8 frames, legs half a cycle apart, arms opposite to the legs
F={}
N=8
for i in range(N):
    p=2*math.pi*i/N
    def legang(p):
        th=30*math.sin(p)
        kn=50*max(0,math.cos(p))**1.5+6   # knee bends while the leg swings forward
        return (th,kn)
    bob=0 if abs(math.sin(p))>0.7 else -1
    F['walk%d'%i]=pose(legang(p+math.pi),legang(p),(18*math.sin(p),45),(-22*math.sin(p),45),bob)
G=((20,115),(12,110))   # guard: upper arm down-forward, forearm forward-up
F['idle0']=pose((-10,8),(14,12),*G)
F['idle1']=pose((-10,12),(14,16),*G,bob=1)
F['punch0']=pose((-14,10),(18,16),(20,115),(-25,140),lean=-1)
F['punch1']=pose((-18,6),(22,10),(20,115),(88,2),lean=1)
F['punch2']=pose((-16,8),(20,12),(20,115),(55,60),lean=0)
F['crouch']=pose((20,75),(40,90),(30,100),(20,100),bob=3)
F['rise']=pose((-10,20),(75,105),(-30,50),(95,30),bob=-1)
F['fall']=pose((-20,30),(30,25),(-50,30),(70,40),bob=-1)
F['land']=pose((25,80),(45,95),(35,100),(25,100),bob=3)
if __name__=='__main__':
    sc=8;ks=list(F);sheet=Image.new('RGBA',(38*len(ks)*sc//2,40*sc*2),(60,70,110,255))
    for i,k in enumerate(ks):
        sheet.alpha_composite(F[k].resize((36*sc,38*sc),Image.NEAREST),((i%9)*38*sc//1//2*1,(i//9)*40*sc))
    sheet.save('sheet2.png')
