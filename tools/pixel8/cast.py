# other characters built on the same rig: swap head/torso/palette
exec(open('rig8.py').read().replace("if __name__=='__main__':",'if False:'))
import copy
BRO=(HEAD,TORSO,dict(P))
PM_HEAD=["...KKKKKK...",
"..KjjjjHHKK.",
".KjjHHHHHHHK",
"KHHHHHHHjjHK",
"KHhHHHHHHHHK",
"KhHHSSSSSSSK",
"KhHSSSSSSSSK",
"KhSsSSKSSKSK",
"KhgsSSSSSSSK",
".KhsSSSSsSSK",
"..KsSSSSKKSK",
"...KSSSSSSK.",
"....KKKKKK.."]
PM_TORSO=["..KRRKSSKK..",
".KRRRRTTRRK.",
"KRQRRRTTRRRK",
"KRQRRRTTRRRK",
"KRQRRRTTRRrK",
"KRRRRRTTRRrK",
"KRRRRRTtRRrK",
"KRRRRRRtRRrK",
".KKKKKKKKKK."]
PM_PAL=dict(P,H=(232,190,90),h=(170,120,50),j=(252,232,150),g=(40,40,40),
 R=(150,192,240),r=(88,122,190),Q=(214,234,255),T=(200,36,60),t=(130,20,40),
 B=(196,164,112),b=(140,110,72),n=(232,208,152),W=(120,64,30),w=(78,42,20))
def as_char(ch):
    global HEAD,TORSO
    HEAD,TORSO=ch[0],ch[1]; P.clear(); P.update(ch[2])
def pm_frames():
    as_char((PM_HEAD,PM_TORSO,PM_PAL))
    out={'idle0':pose((-8,6),(10,8),(10,20),(5,15)),'idle1':pose((-8,8),(10,10),(10,20),(5,15),bob=1),
         'throw0':pose((-12,8),(16,12),(10,20),(-120,-30),lean=-1),
         'throw1':pose((-16,6),(20,10),(10,20),(110,-10),lean=1)}
    for i in range(8):
        p=2*math.pi*i/8
        lg=lambda p:(20*math.sin(p),40*max(0,math.cos(p))**1.5+6)
        out['walk%d'%i]=pose(lg(p+math.pi),lg(p),(15*math.sin(p),20),(-18*math.sin(p),20),0 if abs(math.sin(p))>0.7 else -1)
    as_char(BRO); return out
