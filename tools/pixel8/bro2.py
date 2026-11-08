from PIL import Image
exec(open('bro.py').read().split('def show')[0])
GUARD=[".KK.....",
"KRRK....",
"KRQKKKK.",
"KRRRRRSSK",
"KrrrrrSsK",
".KKKKKKK."]
PUNCH=[".KKKKKKKKKK..",
"KRRRRRRRRKSSK",
"KRQRRRRRRKSSSK",
"KrrrrrrrrKSsSK",
".KKKKKKKKKKKK."]
WIND=[".KK...",
"KRRK..",
"KRQKK.",
"KSSRRK",
"KSsrrK",
".KKKK."]
DOWN=[".KK.","KRRK","KRQK","KrrK","KRRK","KRRK","KSSK","KSsK",".KK."]
L_IDLE=["..KKKKKKKKK...",
".KBBBBBBBnBK..",
".KbBBBKKBBnBK.",
".KbBBK..KBBnK.",
"KbbBK....KBBK.",
"KbBK.....KBnBK",
"KbBK......KBBK",
"KbbK......KBnK",
"KbbK......KbbK",
"KwWWK....KWWWWK",
"KWWWWK...KwWWWWK",
"KKKKKK...KKKKKKK"]
L_W1=["..KKKKKKKKK...",
".KbBBBBBBnBK..",
".KbbBBBBBBnK..",
"KbbK.KKBBBnK..",
"KbbK...KBBnBK.",
"KbbK....KBBnK.",
"KbbK.....KBBK.",
"KbbK.....KBnBK",
"KwwK......KBBK",
"KwwK......KWWWK",
"KKwwK.....KWWWWK",
".KKKK.....KKKKKK"]
L_W2=["...KKKKKKKK...",
"..KbBBBBBnBK..",
"..KbbBBBBBnK..",
"..KbbKBBBBnK..",
"...KbbKBBnK...",
"....KbbBBnK...",
"....KbKBBBK...",
"...KwwKBBnK...",
"...KKKKBnBK...",
"......KBBBK...",
"......KWWWWK..",
"......KKKKKK.."]
L_W3=["..KKKKKKKKK...",
".KBBBBBBBbbK..",
".KBnBBBBbbbK..",
"KBnBK.KKbbbK..",
"KBBK...KbbbK..",
"KBnK....KbbK..",
"KBBK....KbbbK.",
"KBnK.....KbbK.",
"KWWK.....KbbK.",
"KWWK......KwwwK",
"KKWWK.....KwwwwK",
".KKKK.....KKKKKK"]
L_W4=["...KKKKKKKK...",
"..KBBBBBBbbK..",
"..KBnBBBbbbK..",
"..KBnBKbbbK...",
"...KBnKbbbK...",
"....KBBKbbK...",
"....KBBKbbK...",
"...KWWKbbbK...",
"...KKKKbbbK...",
"......KbbbK...",
"......KwwwwK..",
"......KKKKKK.."]
L_JUMP=["..KKKKKKKKK..",
".KbBBBBBBnBK.",
".KbbBBBBBBnK.",
".KbbKKBBBBBnK",
"..KbbKKKKBBnK",
"..KbbK..KWWWK",
"..KwwK..KWWWK",
"..KwwK...KKK.",
"...KK........"]
def dark(g): return [r.translate(str.maketrans('RQSn','rrsb')) for r in g]
def comp(parts,W=34,H=36):
    im=Image.new('RGBA',(W,H),(0,0,0,0))
    for g,x,y in parts:
        for j,r in enumerate(g):
            for i,c in enumerate(r):
                if c in P: im.putpixel((x+i,y+j),P[c]+(255,))
    return im
def frame(legs,arm='guard',bob=0,lean=0,ly=None):
    y0=bob; ly=23 if ly is None else ly
    back={'guard':(dark(GUARD),17+lean,15+y0),'punch':(dark(GUARD),16+lean,15+y0),'wind':(dark(GUARD),15+lean,15+y0),'down':(dark(DOWN),12,16+y0)}[arm]
    front={'guard':(GUARD,15+lean,17+y0),'punch':(PUNCH,15+lean,16+y0),'wind':(WIND,11+lean,17+y0),'down':(DOWN,15,16+y0)}[arm]
    return comp([back,(legs,8,ly+y0 if ly!=23 else 23),(TORSO,9+lean,15+y0),(HEAD,10+lean,3+y0),front])
F={'idle0':frame(L_IDLE),'idle1':frame(L_IDLE,bob=1),
'walk0':frame(L_W1,bob=1),'walk1':frame(L_W2),'walk2':frame(L_W3,bob=1),'walk3':frame(L_W4),
'punch0':frame(L_IDLE,'wind',lean=-1),'punch1':frame(L_IDLE,'punch',lean=1),
'jump':frame(L_JUMP,'down',ly=22,bob=-2)}
import json
sc=8;ks=list(F);sheet=Image.new('RGBA',(36*len(ks)*sc,38*sc),(60,70,110,255))
for i,k in enumerate(ks):
    sheet.alpha_composite(F[k].resize((34*sc,36*sc),Image.NEAREST),(i*36*sc,sc))
sheet.save('sheet.png')
for k,v in F.items(): v.save('f_'+k+'.png')
