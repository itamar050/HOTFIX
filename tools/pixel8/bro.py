from PIL import Image
P={'K':(14,10,24),'H':(150,78,30),'h':(92,44,18),'j':(206,124,56),'S':(252,200,160),'s':(214,132,98),
'L':(160,220,252),'l':(255,255,255),'R':(206,40,44),'r':(122,18,42),'Q':(248,104,80),'T':(44,48,80),'t':(26,26,50),
'B':(52,84,196),'b':(30,40,118),'n':(98,140,236),'W':(240,240,236),'w':(150,150,170),'g':(70,70,90)}
HEAD=["...KKKKKK...",
"..KjjjHHHKK.",
".KjHHHHHHHHK",
"KHHHHHHHHHHK",
"KHhHHHHHHhHK",
"KhHHHSSHSSSK",
"KhHHSSSSSSSK",
"KhHsKKKKKKKK",
"KhssSKLlKLlK",
"KhhSSKKKKKKK",
".KhsSSSSSsSK",
"..KsSSSSKKK.",
"...KKKKK...."]
TORSO=["..KRRKSSKK..",
".KRRRrTTrRK.",
"KRQRRrTTrRRK",
"KrrrrrTTrrrK",
"KRQRRrTTrRRK",
"KRRRRrTTrRRK",
"KrrrrrTTrrrK",
"KRQRRrTTrRRK",
".KKKKKKKKKK."]
def show(rows,name,sc=10):
    w=max(len(r) for r in rows);im=Image.new('RGBA',(w,len(rows)),(80,90,120,255))
    for y,r in enumerate(rows):
        for x,c in enumerate(r):
            if c in P: im.putpixel((x,y),P[c]+(255,))
    im.resize((w*sc,len(rows)*sc),Image.NEAREST).save(name)
show(HEAD+["..."+t for t in TORSO],'t.png')
