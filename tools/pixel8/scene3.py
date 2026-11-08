import math,random
from PIL import Image,ImageDraw,ImageOps
src=open('scene.py').read(); src=src[:src.index('frames=[]')]
src=src.replace("'H':'101101111101101'","'H':'101101111101101','$':'011110010011110','W':'101101101111101','V':'101101101101010','J':'001001001101010','!':'010010010000010','?':'110001010000010'")
src=src.replace("text(d,96,2,'BUGS',(252,252,252),False)\ntext(d,96,9,'0042',(252,200,60),False)","")
src=src.replace("text(d,340,2,'-GLITCH-',(252,252,252),False)","text(d,322,2,'-TEAM LEAD-',(252,252,252),False)")
src=src.replace("pips(340,8,8,8,(176,72,232))","pips(340,8,8,8,(232,160,40))")
src=src.replace("pips(6,8,8,6,(232,40,40)); ","")
exec(src)
exec(open('cast.py').read()); exec(open('props.py').read())
PMF=pm_frames(); PMF={k:ImageOps.mirror(v) for k,v in PMF.items()}
FOOT=F['idle0'].getbbox()[3]
spr=lambda g,p:grid(g,p)
BUGI=[grid(b,BUGP) for b in BUG]; JIRAI=grid(JIRA,JP); NOTEI=[grid(n,NP) for n in NOTE]; COINI=[grid(c,CP) for c in COIN]
def ground(x,y_prev,y_new):
    if 112<=x<=183 and y_prev<=180<=y_new: return 180
    if y_new>=208: return 208
    return None
# ---- state
bro=dict(x=30.0,y=208.0,vx=0.0,vy=0.0,st='idle',t=0,hp=6,inv=0,face=1)
money=0; shown_money=0
bug=dict(x=170.0,alive=True)
jira=dict(x=300.0,y=150.0,alive=True)
coins=[]; notes=[]; pops=[]; texts=[]
pm=dict(st='idle0',t=0,throws=0)
frames=[]; drops=[(rnd.randint(0,W),rnd.randint(32,170)) for _ in range(40)]
plan_jump=False
for n in range(280):
    b=bro
    # --- PM: throw a sticky-note task every 70 ticks
    pm['t']+=1
    cyc=(n+40)%70
    pm['st']='throw0' if 0<=cyc<8 else ('throw1' if 8<=cyc<14 else 'idle%d'%((n//10)%2))
    if cyc==8:
        notes.append(dict(x=236.0,y=170.0,vx=-2.3,vy=-1.6))
    # --- bro controller
    def reach(tx,ty): return abs(tx-(b['x']+30))<12 and abs(ty-(b['y']-16))<16
    if b['st']=='hurt':
        b['t']+=1; b['x']+=b['vx']
        if b['t']>10: b['st']='idle'; b['t']=0
    elif b['st'] in('punch',):
        b['t']+=1
        if b['t']==3:
            if bug['alive'] and reach(bug['x']+8,203):
                bug['alive']=False; pops.append([bug['x']+8,202,0]); texts.append([bug['x'],188,0,'+$'])
                for i in range(5): coins.append(dict(x=bug['x']+8,y=200.0,vx=random.Random(i).uniform(-1.6,1.6),vy=-3.5-i*0.4,t=0))
            if jira['alive'] and reach(jira['x']+11,jira['y']+8):
                jira['alive']=False; pops.append([jira['x']+11,jira['y']+8,0]); texts.append([jira['x'],jira['y']-10,0,'CLOSED!'])
                for i in range(6): coins.append(dict(x=jira['x']+11,y=jira['y']+8,vx=random.Random(9+i).uniform(-1.8,1.4),vy=-2.5-i*0.4,t=0))
        if b['t']>=9: b['st']='idle'; b['t']=0
    elif b['st']=='crouch':
        b['t']+=1
        if b['t']>=3: b['st']='air'; b['vy']=-7.6; b['vx']=2.0
    elif b['st']=='air':
        b['vy']+=0.6; ny=b['y']+b['vy']; b['x']+=b['vx']
        gy=ground(b['x']+16,b['y'],ny) if b['vy']>0 else None
        if gy: b['y']=gy; b['st']='land'; b['t']=0; b['vx']=0
        else: b['y']=ny
    elif b['st']=='land':
        b['t']+=1
        if b['t']>=4: b['st']='idle'; b['t']=0
    else:
        # decide
        target=None
        if bug['alive'] and b['y']==208:
            if reach(bug['x']+8,203): b['st']='punch'; b['t']=0
            else: b['st']='walk'
        elif b['y']==208:
            near=[c for c in coins if c['y']>195 and c['x']>b['x']-4]
            if b['x']<84: b['st']='walk'
            elif not plan_jump: plan_jump=True; b['st']='crouch'; b['t']=0
        else:
            desk=[c for c in coins if c.get('rest') and c['y']<190 and c['x']>b['x']+18]
            if jira['alive'] and reach(jira['x']+11,jira['y']+8): b['st']='punch'; b['t']=0
            elif not jira['alive'] and desk and b['x']<160: b['st']='walk'
            else: b['st']='idle'
        if b['st']=='walk': b['x']+=1.07; b['t']+=1
        elif b['st']=='idle': b['t']+=1
    # --- world
    if bug['alive']: bug['x']-=0.5
    if jira['alive']:
        jira['x']-=0.9 if jira['x']>150 else 0
        jira['y']=150+3*math.sin(n/6)
    for c in coins:
        c['t']+=1
        if c.get('rest'):continue
        c['vy']+=0.35; ny=c['y']+c['vy']; c['x']+=c['vx']
        gy=ground(c['x'],c['y']+4,ny+4)
        if gy and c['vy']>0:
            c['y']=gy-4; c['vy']*=-0.45; c['vx']*=0.6
            if abs(c['vy'])<0.8: c['rest']=True
        else: c['y']=ny
    for c in list(coins):
        if abs(c['x']-(b['x']+16))<9 and abs(c['y']-(b['y']-12))<14:
            coins.remove(c); money+=5; sfx=1
    for nt in list(notes):
        nt['vy']+=0.12; nt['x']+=nt['vx']; nt['y']+=nt['vy']
        if b['inv']==0 and abs(nt['x']-(b['x']+16))<8 and b['y']-34<nt['y']<b['y']:
            notes.remove(nt); b['hp']-=1; b['inv']=24; b['st']='hurt'; b['t']=0; b['vx']=-1.2
            texts.append([b['x']+4,b['y']-46,0,'NEW TASK!'])
        elif nt['y']>206 or nt['x']<-10: notes.remove(nt); pops.append([nt['x'],min(nt['y'],205),0])
    if b['inv']>0: b['inv']-=1
    if shown_money<money: shown_money+=1
    # --- draw
    im=BG.copy(); dd=ImageDraw.Draw(im)
    for (rx,ry) in drops:
        yy=32+((ry-32+n*6)%140)
        if any(x0<=rx<x0+96 and not(x0+47<=rx<=x0+49) for x0 in [28,152,276]) and yy<170 and not(98<=yy<=101):
            dd.line([(rx,yy),(rx-1,yy+3)],fill=(110,120,190))
    for i,(lx,ly) in enumerate([(8,124),(14,136),(20,150),(36,146),(44,158),(10,170),(40,176)]):
        on=(n//3+i*2)%5!=0; im.putpixel((lx,ly),((80,255,120) if i%3 else (255,70,70)) if on else (40,44,60))
    for j in range(4): rect(dd,126,163+j*2,6+((n//2+j*3)%8),1,(88,248,152))
    # HUD dynamic
    pipsd=lambda x,y,nn,full,col:[ (rect(dd,x+i*7,y,6,6,KK),rect(dd,x+i*7+1,y+1,4,4,col if i<full else (60,50,60))) for i in range(nn)]
    pipsd(6,8,8,b['hp'],(232,40,40))
    text(dd,96,2,'CASH',(252,252,252),False); text(dd,96,9,'$%04d'%shown_money,(252,200,60),False)
    # second jira ticket drifting high (decor)
    im.alpha_composite if False else None
    def put(img,x,y):
        im.paste(img,(int(x),int(y)),img)
    put(JIRAI,330,84+3*math.sin(n/7+1))
    put(PMF[pm['st']],226,160-FOOT)
    if bug['alive']: put(BUGI[(n//4)%2],bug['x'],196)
    if jira['alive']: put(JIRAI,jira['x'],jira['y'])
    for c in coins: put(COINI[(c['t']//3)%4],c['x']-3,c['y']-3)
    for nt in notes: put(NOTEI[(n//3)%2],nt['x']-3,nt['y']-3)
    for p in list(pops):
        k=p[2]; p[2]+=1
        for a in range(8):
            ang=a*math.pi/4; r=2+k*2
            xx,yy=int(p[0]+r*math.cos(ang)),int(p[1]+r*math.sin(ang))
            if 0<=xx<W and 0<=yy<H: im.putpixel((xx,yy),(255,240,120) if k%2 else (255,255,255))
        if k>6: pops.remove(p)
    for tx in list(texts):
        text(dd,int(tx[0]),int(tx[1]-tx[2]//2),tx[3],(252,220,80)); tx[2]+=1
        if tx[2]>24: texts.remove(tx)
    st=b['st']
    if st=='walk': fr='walk%d'%((b['t']//2)%8)
    elif st=='idle': fr='idle%d'%((n//8)%2)
    elif st=='punch': fr='punch0' if b['t']<2 else ('punch1' if b['t']<6 else 'punch2')
    elif st=='air': fr='rise' if b['vy']<0 else 'fall'
    elif st=='hurt': fr='fall'
    else: fr=st
    if not(b['inv']>0 and n%2): put(F[fr],b['x'],b['y']-FOOT)
    frames.append(im.convert('RGB').resize((W*3,H*3),Image.NEAREST))
frames[0].save('mock3.gif',save_all=True,append_images=frames[1:],duration=50,loop=0)
for i in [30,70,110,150,200,250]: frames[i].save('m3_%d.png'%i)
print(money,b['hp'],b['x'],b['y'])
