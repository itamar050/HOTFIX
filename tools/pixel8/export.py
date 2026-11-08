"""Export the 8-bit art to godot/game8/art/ and write godot/game8/sprite_data.gd.
Run from tools/pixel8: python3 export.py"""
import math, os, random
from PIL import Image, ImageDraw
exec(open('cast.py').read())
exec(open('props.py').read())
OUT='../../godot/game8/art'; os.makedirs(OUT,exist_ok=True)
KK=(14,10,24)
data=[]
def strip(name,frames,cw,ch,hipx):
    """frames: dict name->RGBA image; body centre (hipx) goes to the cell centre"""
    names=list(frames); im=Image.new('RGBA',(cw*len(names),ch),(0,0,0,0))
    dx=round(cw/2-hipx); foot=0
    for i,k in enumerate(names):
        f=frames[k]; im.alpha_composite(f,(i*cw+dx,ch-f.height-0))
    # foot = lowest opaque row of the first frame (idle)
    first=im.crop((0,0,cw,ch)); foot=first.getbbox()[3]
    im.save(f'{OUT}/{name}.png')
    data.append((name,cw,ch,foot,names))
# ---------- Code Bro
F['hurt']=pose((-25,30),(10,40),(-60,40),(-50,40),lean=-1)
F['airpunch']=pose((-10,40),(40,70),(20,115),(88,2),bob=-1)
bro={k:F[k] for k in ['idle0','idle1']+['walk%d'%i for i in range(8)]+['punch0','punch1','punch2','crouch','rise','fall','land','hurt','airpunch']}
strip('bro',bro,40,40,15.5)
# ---------- PM
pm=pm_frames(); as_char((PM_HEAD,PM_TORSO,PM_PAL)); pm['hurt']=pose((-20,30),(10,40),(-60,40),(-50,40),lean=-1); as_char(BRO)
strip('pm',pm,40,40,15.5)
# ---------- Team Leader boss: about twice Code Bro's height, same pixel scale
TL_HEAD=[".......KKKKKKKK.......",
".....KKHHHHHHHHKK.....",
"....KHHHHjjHHHHHHK....",
"...KHHHjjHHHHHHHHHK...",
"..KHHHHHHHHHHHHHHHHK..",
"..KHhHHHHHHHHHHHHHHHK.",
".KHhHHHHHHHHHHHHHHHHK.",
".KHhHHHHSSSSSSSSSSSHK.",
".KhHHHSSSSSSSSSSSSSSK.",
".KhgHSSSSSSSSSSSSSSSK.",
".KggsSSSSSSKKKSSSKKKK.",
"KgGgsSSSSSSSKSSSSSKSSK",
"KgGgssSSSSSSSSSSSSSSSK",
"KgGgsSSSSSSSSSSSSSssSK",
".KhgDDSSSSSSSSSSSSSSK.",
"..KgDDDSSSSSSSSSSSDDK.",
"..KDgDDDDDDDKKKKKDDDK.",
"..KDDgggggDDDDDDDDDDK.",
"...KDDDDDDDDDDDDDDDK..",
"....KDDDDDDDDDDDDDK...",
".....KKDDDDDDDDDKK....",
".......KKKKKKKKK......"]
TL_TORSO=[".......KKKKSSSSKKKK.......",
".....KKRRRRKSSKRRRRKK.....",
"...KKRRRRRRRKKRRRRRRRKK...",
"..KRRRQRRRRRRRRRRRRRRRRK..",
".KRRRQRRRRRRvRRvRRRRRRRRK.",
".KRRQRRRRRRRvRRvRRRRRRRRK.",
"KRRRQRRRRRRRvRRvRRRRRRRrRK",
"KRRQRRRRRTTTTTTTTRRRRRRrRK",
"KRRQRRRRRTttTTttTRRRRRRrRK",
"KRRQRRRRRTTTTTTTTRRRRRRrRK",
"KRRQRRRRRRRRRRRRRRRRRRRrRK",
"KRRRRRRRRRRRRRRRRRRRRRrrRK",
"KRRRRRKKKKKKKKKKKKRRRRrrRK",
"KRRRRRKrrrrrrrrrrKRRRRrrRK",
"KRRRRRKrrrrrrrrrrKRRRRrrRK",
"KrRRRRRKKKKKKKKKKRRRRrrrRK",
"KrrRRRRRRRRRRRRRRRRRRrrrrK",
"KrrrrrrrrrrrrrrrrrrrrrrrrK",
".KrrrrrrrrrrrrrrrrrrrrrrK.",
"..KKKKKKKKKKKKKKKKKKKKKK.."]
TL_PAL=dict(P,H=(60,40,30),h=(36,24,18),j=(96,66,46),g=(40,40,48),G=(90,90,104),D=(84,54,36),
 R=(92,96,118),r=(56,58,76),Q=(140,146,170),T=(232,160,40),t=(150,90,20),w=(230,230,240),
 B=(44,52,96),b=(28,32,64),n=(80,92,150),W=(220,44,44))
TL_PAL['v']=(230,230,240); TL_PAL['w']=(140,28,28)
SAVE_GEO=dict(GEO)
GEO.update(hip=(30.5,38.5),sb=(34,24),sf=(26,24),torso=(17,20),head=(21,0),leg=(11.0,10.0,8.4),arm=(9.0,8.5,7.0),fist=7.4,shoe=(13,4))
as_char((TL_HEAD,TL_TORSO,TL_PAL))
# legs/shoes: the shoe colour letters W/w are shared with the hoodie strings, so shoes use W only
TP=lambda *a,**k: pose(*a,W=64,H=74,**k)
tl={'idle0':TP((-10,8),(12,12),(15,40),(10,30)),'idle1':TP((-10,12),(12,16),(15,40),(10,30),bob=1)}
for i in range(8):
    p=2*math.pi*i/8; lg=lambda p:(24*math.sin(p),40*max(0,math.cos(p))**1.5+6)
    tl['walk%d'%i]=TP(lg(p+math.pi),lg(p),(16*math.sin(p),30),(-18*math.sin(p),30),0 if abs(math.sin(p))>0.7 else -1)
tl['throw0']=TP((-12,8),(16,12),(15,40),(-150,10),lean=-2)
tl['throw1']=TP((-16,6),(20,10),(15,40),(100,-10),lean=2)
tl['crouch']=TP((30,80),(50,95),(30,100),(20,100),bob=7)
tl['air']=TP((-10,30),(60,90),(150,10),(160,10),bob=-2)
tl['land']=TP((30,85),(50,100),(-60,20),(-50,20),bob=7)
tl['dash0']=TP((-30,20),(40,30),(-80,10),(-70,10),lean=3)
tl['dash1']=TP((-10,50),(20,10),(-80,10),(-70,10),lean=3)
tl['dizzy0']=TP((-12,20),(14,24),(-10,10),(-5,10),bob=3,lean=-1)
tl['dizzy1']=TP((-12,20),(14,24),(-10,10),(-5,10),bob=3,lean=1)
tl['hurt']=TP((-25,30),(10,40),(-60,40),(-50,40),lean=-3)
strip('tl',tl,72,74,30.5)
as_char(BRO); GEO.clear(); GEO.update(SAVE_GEO)
# ---------- small sprites
def save_frames(name,grids,pal):
    ims=[grid(g,pal) for g in grids]; w=max(i.width for i in ims); h=max(i.height for i in ims)
    out=Image.new('RGBA',(w*len(ims),h),(0,0,0,0))
    for i,im in enumerate(ims): out.alpha_composite(im,(i*w+(w-im.width)//2,h-im.height))
    out.save(f'{OUT}/{name}.png'); data.append((name,w,h,h,[str(i) for i in range(len(ims))]))
save_frames('bug',BUG,BUGP)
save_frames('jira',[JIRA],JP)
save_frames('note',NOTE,NP)
save_frames('coin',COIN,CP)
# ---------- props (drawn with rectangles, black outline)
def canvas(w,h): im=Image.new('RGBA',(w,h),(0,0,0,0)); return im,ImageDraw.Draw(im)
def R(d,x,y,w,h,c): d.rectangle([x,y,x+w-1,y+h-1],fill=c)
def desk():
    im,d=canvas(72,28)
    R(d,0,0,72,6,KK);R(d,1,1,70,4,(170,178,200));R(d,1,1,70,1,(230,236,248));R(d,1,4,70,1,(110,116,140))
    for lx in [3,65]: R(d,lx,6,4,22,KK);R(d,lx+1,6,2,22,(90,96,120))
    R(d,42,6,22,18,KK);R(d,43,7,20,16,(120,126,150));R(d,44,12,18,1,KK)
    return im
def monitor():
    im,d=canvas(20,20); R(d,0,0,20,15,KK);R(d,2,2,16,10,(0,120,60));R(d,8,15,4,3,KK);R(d,5,18,10,2,KK)
    for j in range(4): R(d,3,3+j*2,5+(j*5)%9,1,(88,248,152))
    return im
def cabinet(h):
    im,d=canvas(30,h); R(d,0,0,30,h,KK);R(d,1,1,28,h-2,(96,100,128));R(d,1,1,28,1,(160,164,196))
    for yy in range(3,h-4,12): R(d,3,yy,24,10,(76,80,106));R(d,11,yy+4,8,2,(190,190,210))
    return im
def shelf(w):
    im,d=canvas(w,14); R(d,0,0,w,8,KK);R(d,1,1,w-2,6,(110,90,60));R(d,1,1,w-2,2,(180,148,96));R(d,1,6,w-2,1,(70,52,36))
    for bx in [6,w-10]: R(d,bx,8,4,6,KK)
    return im
def books():
    im,d=canvas(26,12)
    for i,c in enumerate([(200,60,60),(60,120,200),(230,200,80),(80,180,100),(200,60,60)]): R(d,i*5,0,4,12,KK);R(d,i*5+1,1,2,10,c)
    return im
def rack(h):
    im,d=canvas(26,h); R(d,0,0,26,h,KK);R(d,2,2,22,h-4,(40,44,60))
    for yy in range(4,h-6,6): R(d,3,yy,20,4,(28,30,44));R(d,3,yy,20,1,(70,76,100))
    return im
def cooler():
    im,d=canvas(18,38); R(d,0,0,18,38,KK);R(d,1,16,16,21,(200,204,220));R(d,2,1,14,15,(90,170,240));R(d,3,2,4,10,(170,220,255));R(d,6,22,4,3,KK)
    return im
def plant():
    im,d=canvas(14,30)
    PL=["....K..K.....","...KgK.KgK...","..KgvK.KgvK..",".KKgvKKgvgKK.","KgvKgvgvgKvgK","KgvgKgvgKgvgK",".KgvgKgKgvgK.","..KKgvgvgKK..","....KgvgK....",".....KKK....."]
    pal={'K':KK,'g':(30,130,60),'v':(110,210,100)}
    for j,r in enumerate(PL):
        for i,c in enumerate(r):
            if c in pal: d.point((i,j),fill=pal[c])
    R(d,0,12,14,16,KK);R(d,1,13,12,14,(170,90,50));R(d,1,13,12,2,(220,130,80))
    return im
def vending():
    im,d=canvas(40,64); R(d,0,0,40,64,KK);R(d,1,1,38,62,(180,30,40));R(d,1,1,38,2,(240,90,90))
    R(d,4,6,22,44,KK);R(d,5,7,20,42,(30,40,70))
    for r_ in range(4):
        for c_ in range(3): R(d,7+c_*6,10+r_*10,4,6,[(250,200,60),(90,200,250),(120,230,110),(250,120,200)][(r_+c_)%4])
    R(d,29,8,8,10,KK);R(d,30,9,6,8,(60,240,140));R(d,29,22,8,16,(220,220,230));R(d,5,54,30,6,KK)
    return im
def lamp():
    im,d=canvas(16,14); R(d,7,0,2,10,KK);R(d,0,10,16,4,KK);R(d,1,11,14,2,(250,240,180)); return im
def door():   # the boss room door (glass, NEXUS logo)
    im,d=canvas(40,72); R(d,0,0,40,72,KK);R(d,2,2,36,70,(70,52,110));R(d,5,5,30,40,(120,170,230));R(d,6,6,10,30,(180,215,250))
    R(d,30,46,4,8,(250,210,80)); return im
def item_keyboard():
    im,d=canvas(18,7); R(d,0,0,18,7,KK);R(d,1,1,16,5,(70,74,96));R(d,1,1,16,1,(120,126,150))
    for r_ in range(2):
        for c_ in range(7): R(d,2+c_*2,2+r_*2,1,1,(220,224,240))
    R(d,5,5,8,1,(220,224,240)); return im
def item_ooo():
    im,d=canvas(15,9); R(d,0,0,15,9,KK);R(d,1,1,13,7,(190,150,250));R(d,1,1,13,1,(225,200,255))
    for k in range(3):
        x=2+k*4; R(d,x,3,3,3,KK); R(d,x+1,4,1,1,(190,150,250))
    return im
props=dict(keyboard=item_keyboard(),ooo=item_ooo(),desk=desk(),monitor=monitor(),cab48=cabinet(48),cab24=cabinet(24),shelf=shelf(84),books=books(),rack90=rack(90),rack68=rack(68),
           cooler=cooler(),plant=plant(),vending=vending(),lamp=lamp(),door=door())
for k,v in props.items(): v.save(f'{OUT}/prop_{k}.png')
# ---------- background layers
def far():
    im,d=canvas(400,240)
    sky=[(10,8,40),(18,14,58),(28,20,78),(40,28,96)]
    for i,c in enumerate(sky): R(d,0,i*44,400,44 if i<3 else 120,c)
    def city(col,win,base,hmin,hmax,wmin,wmax,seed):
        r=random.Random(seed);x=0
        while x<400:
            w=min(r.randint(wmin,wmax),400-x);h=r.randint(hmin,hmax);top=base-h
            R(d,x,top,w,base-top+40,col)
            if r.random()<.3 and w>6: R(d,x+w//2-1,top-8,2,8,col)
            for yy in range(top+4,base-4,6):
                for xx in range(x+3,x+w-3,5):
                    if r.random()<.35: R(d,xx,yy,2,3,win if r.random()<.7 else tuple(v//2 for v in win))
            x+=w+r.randint(0,4)
    city((30,24,80),(150,120,70),180,40,110,18,34,1)
    city((20,16,56),(232,200,104),180,20,70,24,44,2)
    d.ellipse([214,30,238,54],fill=(236,232,200)); d.ellipse([208,26,230,48],fill=sky[0])
    return im
def wall():   # one 124 px wall segment: pillar + window frame, panes transparent
    im,d=canvas(124,240)
    WALL=(54,36,92);WD=(34,22,62);WL=(92,66,140)
    R(d,0,0,124,28,(24,18,40))
    for x in range(0,124,8): R(d,x,26,6,2,(40,30,64))
    R(d,0,0,124,16,KK)
    R(d,0,28,28,150,WALL);R(d,0,28,2,150,WL);R(d,26,28,2,150,WD)
    R(d,8,60,12,20,WD);R(d,9,61,10,18,(70,200,120))
    x0=28; R(d,x0,28,96,4,KK);R(d,x0+47,28,3,150,KK);R(d,x0,98,96,3,KK);R(d,x0,174,96,4,KK)
    R(d,0,178,124,30,(42,28,72))
    for x in range(0,124,32): R(d,x,178,2,30,(30,20,52))
    R(d,0,178,124,2,(80,60,124))
    R(d,0,208,124,32,(30,22,50))
    return im
def floor():
    im,d=canvas(16,16); FT=(84,68,124)
    R(d,0,0,16,16,FT);R(d,0,0,16,1,(140,124,192));R(d,0,0,1,16,(100,84,148));R(d,15,0,1,16,(48,36,80));R(d,0,15,16,1,(48,36,80))
    return im
def floor2():
    im=floor(); d=ImageDraw.Draw(im); R(d,0,0,16,1,(100,84,148)); return im
far().save(f'{OUT}/bg_far.png'); wall().save(f'{OUT}/bg_wall.png'); floor().save(f'{OUT}/tile_floor.png'); floor2().save(f'{OUT}/tile_floor2.png')
# ---------- GDScript sprite table
with open('../../godot/game8/sprite_data.gd','w') as f:
    f.write('## Generated by tools/pixel8/export.py: frame tables for the 8-bit sprite strips.\nextends RefCounted\n\nconst SHEETS := {\n')
    for name,w,h,foot,names in data:
        f.write('\t"%s": {"w": %d, "h": %d, "foot": %d, "frames": [%s]},\n'%(name,w,h,foot,', '.join('"%s"'%n for n in names)))
    f.write('}\n')
print('\n'.join('%s %dx%d foot %d: %d frames'%(n,w,h,ft,len(nm)) for n,w,h,ft,nm in data))
