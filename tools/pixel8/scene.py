from PIL import Image, ImageDraw
import random, math
src=open('bro2.py').read().split('import json')[0]
src=src.replace('''L_JUMP=["..KKKKKKKKK..",''','''L_JUMP=["..KKKKKKKKK...",
".KbBBBBBBBnK..",
".KbbBBBBBBBnKK",
".KbbKKBBBBBBnK",
"..KbbbKKKKBBnK",
"...KbbK..KBBBK",
"...KwwwK.KWWWK",
"...KwwwK.KWWWWK",
"....KKK...KKKK."]
OLDJ=["..KKKKKKKKK..",''')
exec(src)
exec(open('rig8.py').read().replace("if __name__=='__main__':",'if False:'))
FOOT=max(F['idle0'].getbbox()[3],F['walk0'].getbbox()[3])
W,H=400,240
C=lambda *a:a
def rect(d,x,y,w,h,c): d.rectangle([x,y,x+w-1,y+h-1],fill=c)
# ---------- static background
bg=Image.new('RGB',(W,H)); d=ImageDraw.Draw(bg)
sky=[(10,8,40),(18,14,58),(28,20,78),(40,28,96)]
for i,c in enumerate(sky): rect(d,0,16+i*30,W,30 if i<3 else 140,c)
rnd=random.Random(3)
def city(col,win,base,hmin,hmax,wmin,wmax,seed):
    r=random.Random(seed);x=-10
    while x<W:
        w=r.randint(wmin,wmax);h=r.randint(hmin,hmax);top=base-h
        rect(d,x,top,w,base-top,col)
        if r.random()<.3: rect(d,x+w//2-1,top-8,2,8,col)
        for yy in range(top+4,base-4,6):
            for xx in range(x+3,x+w-3,5):
                if r.random()<.35: rect(d,xx,yy,2,3,win if r.random()<.7 else (win[0]//2,win[1]//2,win[2]//2))
        x+=w+r.randint(0,4)
city((30,24,80),(150,120,70),170,40,110,18,34,1)
city((20,16,56),(232,200,104),170,20,70,24,44,2)
# moon
d.ellipse([214,40,238,64],fill=(236,232,200)); d.ellipse([208,36,230,58],fill=sky[1])
# office window frame: wall pillars + mullions
WALL=(54,36,92);WD=(34,22,62);WL=(92,66,140);KK=(14,10,24)
for px in [0,124,248,372]:
    rect(d,px,28,28,150,WALL);rect(d,px,28,2,150,WL);rect(d,px+26,28,2,150,WD)
    rect(d,px+8,60,12,20,WD); rect(d,px+9,61,10,18,(70,200,120) if px%248==0 else (220,90,90))  # wall posters/screens
for x0 in [28,152,276]:
    rect(d,x0,28,96,4,KK);rect(d,x0+47,28,3,150,KK);rect(d,x0,98,96,3,KK)
    rect(d,x0,174,96,4,KK)
# ceiling
rect(d,0,16,W,12,(24,18,40));
for x in range(0,W,8): rect(d,x,26,6,2,(40,30,64))
# lower wall / baseboard behind floor
rect(d,0,178,W,30,(42,28,72))
for x in range(0,W,32): rect(d,x,178,2,30,(30,20,52))
rect(d,0,178,W,2,(80,60,124))
# server racks (background, blinking later)
def rack(x,y,h):
    rect(d,x,y,26,h,KK);rect(d,x+2,y+2,22,h-4,(40,44,60))
    for yy in range(y+4,y+h-6,6): rect(d,x+3,yy,20,4,(28,30,44));rect(d,x+3,yy,20,1,(70,76,100))
rack(4,118,90); rack(32,140,68)
# floor tiles 16x16
FT=(84,68,124);FL=(140,124,192);FD=(48,36,80)
for ty in range(208,240,16):
    for tx in range(0,W,16):
        rect(d,tx,ty,16,16,FT);rect(d,tx,ty,16,1,FL if ty==208 else (100,84,148));rect(d,tx,ty,1,16,(100,84,148))
        rect(d,tx+15,ty,1,16,FD);rect(d,tx,ty+15,16,1,FD)
rect(d,0,207,W,1,KK)
# platforms: desk, cabinets, vent shelf
def desk(x,y,w):
    rect(d,x,y,w,6,KK);rect(d,x+1,y+1,w-2,4,(170,178,200));rect(d,x+1,y+1,w-2,1,(230,236,248));rect(d,x+1,y+4,w-2,1,(110,116,140))
    for lx in [x+3,x+w-7]: rect(d,lx,y+6,4,208-y-6,KK);rect(d,lx+1,y+6,2,208-y-6,(90,96,120))
    rect(d,x+w-30,y+6,22,18,KK);rect(d,x+w-29,y+7,20,16,(120,126,150));rect(d,x+w-28,y+12,18,1,KK)
def monitor(x,y):
    rect(d,x,y,20,15,KK);rect(d,x+2,y+2,16,10,(0,120,60));rect(d,x+8,y+15,4,3,KK);rect(d,x+5,y+18,10,2,KK)
desk(112,180,72); monitor(124,160)
def cabinet(x,y,h):
    rect(d,x,y,30,h,KK);rect(d,x+1,y+1,28,h-2,(96,100,128));rect(d,x+1,y+1,28,1,(160,164,196))
    for yy in range(y+3,y+h-4,12): rect(d,x+3,yy,24,10,(76,80,106));rect(d,x+11,yy+4,8,2,(190,190,210))
cabinet(232,160,48); cabinet(262,184,24)
def shelf(x,y,w):
    rect(d,x,y,w,8,KK);rect(d,x+1,y+1,w-2,6,(110,90,60));rect(d,x+1,y+1,w-2,2,(180,148,96));rect(d,x+1,y+6,w-2,1,(70,52,36))
    for bx in [x+6,x+w-10]: rect(d,bx,y+8,4,6,KK)
shelf(300,132,84)
# books on shelf
for i,c in enumerate([(200,60,60),(60,120,200),(230,200,80),(80,180,100),(200,60,60)]): rect(d,312+i*5,120,4,12,KK);rect(d,313+i*5,121,2,10,c)
# potted plant + water cooler
rect(d,200,192,14,16,KK);rect(d,201,193,12,14,(170,90,50));rect(d,201,193,12,2,(220,130,80))
PL=["....K..K.....",
"...KgK.KgK...",
"..KgvK.KgvK..",
".KKgvKKgvgKK.",
"KgvKgvgvgKvgK",
"KgvgKgvgKgvgK",
".KgvgKgKgvgK.",
"..KKgvgvgKK..",
"....KgvgK....",
".....KKK....."]
blit_pal={'K':KK,'g':(30,130,60),'v':(110,210,100)}
for j,r in enumerate(PL):
    for i,c in enumerate(r):
        if c in blit_pal: d.point((200+i,180+j),fill=blit_pal[c])
rect(d,374,170,18,38,KK);rect(d,375,186,16,21,(200,204,220));rect(d,376,171,14,15,(90,170,240));rect(d,377,172,4,10,(170,220,255))
rect(d,380,192,4,3,KK)
# ceiling lamps
for lx in [90,214,338]: rect(d,lx-1,28,2,10,KK);rect(d,lx-8,38,16,4,KK);rect(d,lx-7,39,14,2,(250,240,180))
# 3x5 font
FONT={'A':'010101111101101','B':'110101110101110','C':'011100100100011','D':'110101101101110','E':'111100110100111','G':'011100101101011','I':'111010010010111','K':'101101110101101','L':'100100100100111','O':'010101101101010','R':'110101110101101','S':'011100010001110','T':'111010010010010','U':'101101101101111','X':'101101010101101','P':'110101110100100','F':'111100110100100','N':'1001110110101011100'[:0]+'111101101101101','M':'101111111101101','H':'101101111101101','Q':'010101101111011','+':'000010111010000','Y':'101101010010010','-':'000000111000000',' ':'0'*15,
'0':'111101101101111','1':'010110010010111','2':'110001010100111','3':'110001010001110','4':'101101111001001','5':'111100110001110','6':'011100110101010','7':'111001010010010','8':'010101010101010','9':'010101011001110',':':'000010000010000'}
def text(dd,x,y,s,c,sh=True):
    for ch in s:
        g=FONT[ch]
        for j in range(5):
            for i in range(3):
                if g[j*3+i]=='1':
                    if sh: dd.point((x+i+1,y+j+1),fill=KK)
                    dd.point((x+i,y+j),fill=c)
        x+=4
# HUD bar
rect(d,0,0,W,16,KK)
text(d,6,2,'-BRO-',(252,252,252),False)
text(d,96,2,'BUGS',(252,252,252),False)
text(d,96,9,'0042',(252,200,60),False)
text(d,170,2,'STAGE 1',(252,252,252),False); text(d,170,9,'NEXUS HQ',(160,200,252),False)
text(d,340,2,'-GLITCH-',(252,252,252),False)
def pips(x,y,n,full,col):
    for i in range(n):
        rect(d,x+i*7,y,6,6,KK);rect(d,x+i*7+1,y+1,4,4,col if i<full else (60,50,60))
        if i<full: d.point((x+i*7+1,y+1),fill=(255,230,230))
pips(6,8,8,6,(232,40,40)); pips(340,8,8,8,(176,72,232))
BG=bg
# ---------- sprites
G_={'G':(40,180,40),'g':(16,96,48),'v':(140,236,100),'w':(255,255,255),'K':KK,'m':(236,60,200)}
BUG=[["....K...K...","....K..K....",".....KK.....","...KKKKKKK..","..KvGGgGGGK.",".KGGGGGgGGKK","KGgGGGGGGKwK","KgGGGgGGGKKK",".KKgKKgKKgK.","..K..K..K...."],
["...K....K...","....K..K....",".....KK.....","...KKKKKKK..","..KvGGgGGGK.",".KGGGGGgGGKK","KGgGGGGGGKwK","KgGGGgGGGKKK",".KKgKKgKKgK.","...K..K..K..."]]
DRONE=["K.KKKK...KKKK.K","...KK.....KK...","....KKKKKKK....","...KwwwwwwwK...","..KwgggggggwK..","..KgggKmKgggK..","...KgggggggK...","....KKKKKKK....","......K.K......"]
D_={'w':(200,204,220),'g':(110,114,140),'K':KK,'m':(255,40,60)}
CUP=["..KKKK..",".KwwwwK.","KKwccwKK","K.KwcK.K",".KwwwwK.",".KKKKKK."]
C_={'w':(240,240,240),'c':(120,72,40),'K':KK}
def blit(im,g,x,y,pal,flip=False):
    w=max(len(r) for r in g)
    for j,r in enumerate(g):
        for i,c in enumerate(r):
            if c in pal:
                xx=x+(w-1-i if flip else i)
                if 0<=xx<W and 0<=y+j<H: im.putpixel((xx,y+j),pal[c])
frames=[]
# timeline with real physics (20 ticks per second)
seq=[]; x=40.0; fy=208.0
bugx=200.0
for t in range(16): seq.append(('idle%d'%((t//8)%2),x,fy))
t=0
while True:
    # walk speed matches the stride so the planted foot does not slide
    x+=1.07; seq.append(('walk%d'%((t//2)%8),x,fy)); t+=1
    if bugx-0.5*len(seq)-(x+30)<2: break
for k,n_ in [('punch0',2),('punch1',4),('punch2',3),('idle0',8)]:
    seq+= [(k,x,fy)]*n_
seq+=[('crouch',x,fy)]*3
vy=-7.6; vx=2.0; g=0.6
while True:
    vy+=g; x+=vx; ny=fy+vy
    feet=x+16
    if vy>0 and 112<=feet<=182 and fy<=180<=ny: fy=180; break
    if ny>=208: fy=208; break
    fy=ny; seq.append(('rise' if vy<0 else 'fall',x,fy))
seq+=[('land',x,fy)]*4
for t in range(24): seq.append(('idle%d'%((t//8)%2),x,fy))
bug_dead=-1
drops=[(rnd.randint(0,W),rnd.randint(32,170)) for _ in range(40)]
for n,(fr,bx,by) in enumerate(seq):
    im=BG.copy(); dd=ImageDraw.Draw(im)
    # rain on window panes
    for (rx,ry) in drops:
        yy=32+((ry-32+n*6)%140)
        if any(x0<=rx<x0+96 and rx!=x0+47 and rx!=x0+48 and rx!=x0+49 for x0 in [28,152,276]) and yy<170 and not(98<=yy<=101):
            dd.line([(rx,yy),(rx-1,yy+3)],fill=(110,120,190))
    # blinking leds
    for i,(lx,ly) in enumerate([(8,124),(14,136),(20,150),(36,146),(44,158),(10,170),(40,176)]):
        on=(n//3+i*2)%5!=0; im.putpixel((lx,ly),((80,255,120) if i%3 else (255,70,70)) if on else (40,44,60))
    # monitor screen scroll
    for j in range(4):
        w_=6+((n//2+j*3)%8); rect(dd,126,163+j*2,w_,1,(88,248,152))
    # coffee pickup bobbing on shelf
    blit(im,CUP,350,122-((n//6)%2),C_)
    # drone hovering
    blit(im,DRONE,300,70+int(4*math.sin(n/5)),D_)
    # bug crawls left until hit
    if fr=='punch1' and bug_dead<0 and abs(bugx-(bx+30))<16: bug_dead=n
    if bug_dead<0:
        bugx-=0.5
        blit(im,BUG[(n//4)%2],int(bugx),198,G_,flip=False)
    elif n-bug_dead<10:
        # pop: sparks + glitch
        k=n-bug_dead
        for a in range(8):
            ang=a*math.pi/4; r=3+k*2
            im.putpixel((int(bugx+6+r*math.cos(ang)),int(202+r*math.sin(ang))),(255,240,120) if k%2 else (236,60,200))
        if k<5: text(dd,int(bugx),186-k,'+10',(252,200,60))
    # shadow + bro
    sh_y=207 if bx<112 or bx>180 else 179
    spr=F[fr]
    im.paste(spr,(int(bx),int(round(by))-FOOT),spr)
    frames.append(im.resize((W*3,H*3),Image.NEAREST))
frames[0].save('mock.gif',save_all=True,append_images=frames[1:],duration=50,loop=0)
frames[min(60,len(frames)-1)].save('still.png')
print(len(frames))
