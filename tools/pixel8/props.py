K=(14,10,24)
def grid(rows,pal):
    from PIL import Image
    w=max(len(r) for r in rows);im=Image.new('RGBA',(w,len(rows)),(0,0,0,0))
    for y,r in enumerate(rows):
        for x,c in enumerate(r):
            if c in pal: im.putpixel((x,y),pal[c]+(255,))
    return im
BUGP={'K':K,'G':(48,190,56),'g':(20,104,52),'v':(150,240,110),'e':(255,60,60),'m':(236,60,200),'l':(30,30,40)}
BUG=[["......K.....K.....",".......K...K......","........K.K.......","....KKKKKKKKKK....","...KvvGGGgGGGGK...","..KvGGGGgGGGGGKK..",".KGGGGGGgGGGGKeeK.",".KGgGGGGgGGGGKeKK.","KgGGgGGGgGGGGGKK..","KggGGGGGgGGGgGK...",".KKKKKKKKKKKKKK...","..K..K...K..K.....",".K..K...K..K......"],
["......K.....K.....","......K.....K.....","........K.K.......","....KKKKKKKKKK....","...KvvGGGgGGGGK...","..KvGGGGgGGGGGKK..",".KGGGGGGgGGGGKeeK.",".KGgGGGGgGGGGKeKK.","KgGGgGGGgGGGGGKK..","KggGGGGGgGGGgGK...",".KKKKKKKKKKKKKK...","...K..K...K..K....","....K..K...K..K..."]]
JP={'K':K,'B':(0,82,204),'L':(56,138,255),'W':(255,255,255),'d':(0,46,130),'r':(255,70,60),'y':(255,220,60)}
JIRA=["KKKKKKKKKKKKKKKKKKKKKK",
"KLLLLLLLLLLLLLLLLLLLLK",
"KLBBBBBBBBBBBBBBBBBBdK",
"KLBBKKBBBBBBBBBBKKBBdK",
"KLBBBKKBBBBBBBBKKBBBdK",
"KLBBWWWKBBBBBBKWWWBBdK",
"KLBBWKWBBBBBBBBWKWBBdK",
"KLBBBBBBBBBBBBBBBBBBdK",
"KLBWWWBBWBBWWBBBWBBBdK",
"KLBBWBBBWBBWBWBBWWBBdK",
"KLBBWBBBWBBWWBBWBWBBdK",
"KLWBWBBBWBBWBWBWWWBBdK",
"KLBWBBBBWBBWBWBWBWBBdK",
"KLBBBBBBBBBBBBBBBBBBdK",
"KdddddddddddddddddddKK",
".KKKKKKKKKKKKKKKKKKKK."]
NOTE=[["KKKKKKK","KyyyyyK","KyKKKyK","KyyyyyK","KyKKyyK","KyyyyyK","KKKKKKK"],
["...K...","..KyK..",".KyyyK.","KyKyKyK",".KyyyK.","..KyK..","...K..."]]
NP={'K':K,'y':(252,228,90)}
CP={'K':K,'Y':(252,200,40),'y':(200,130,20),'w':(255,250,200)}
COIN=[["..KKK..",".KYYYK.","KYwYYyK","KYYYYyK","KYYYyyK",".KyyyK.","..KKK.."],
[".KKK.","KYwyK","KYYyK","KYYyK","KYyyK","KyyyK",".KKK."],
[".K.","KwK","KYK","KYK","KYK","KyK",".K."],
[".KKK.","KYwyK","KYYyK","KYYyK","KYyyK","KyyyK",".KKK."]]
