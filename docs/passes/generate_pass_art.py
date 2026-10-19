import math, random
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops
S=2048; OUT='/home/user/robloxhorror/docs/passes/'
FONT='/usr/share/fonts/opentype/inter/InterDisplay-Bold.otf'
FONTX='/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf'
def radial(c_in,c_out,center=(0.5,0.45),r=0.75):
    img=Image.new('RGB',(S,S))
    px=img.load()
    small=Image.new('RGB',(256,256)); sp=small.load()
    for y in range(256):
        for x in range(256):
            d=math.hypot(x/255-center[0],y/255-center[1])/r
            t=min(1,d)**1.3
            sp[x,y]=tuple(int(c_in[i]*(1-t)+c_out[i]*t) for i in range(3))
    return small.resize((S,S),Image.BICUBIC).convert('RGBA')
def glow(base,shape_fn,color,blur):
    layer=Image.new('RGBA',(S,S),(0,0,0,0)); d=ImageDraw.Draw(layer); shape_fn(d,color)
    g=layer.filter(ImageFilter.GaussianBlur(blur))
    base.alpha_composite(g)
def sparkles(img,color,n,seed):
    rnd=random.Random(seed); d=ImageDraw.Draw(img)
    for _ in range(n):
        x,y=rnd.uniform(200,1850),rnd.uniform(200,1850)
        if math.hypot(x-1024,y-1024)>880: continue
        r=rnd.uniform(6,22); a=rnd.randint(90,220)
        d.polygon([(x,y-r*3),(x+r*0.6,y-r*0.6),(x+r*3,y),(x+r*0.6,y+r*0.6),(x,y+r*3),(x-r*0.6,y+r*0.6),(x-r*3,y),(x-r*0.6,y-r*0.6)],fill=color+(a,))
def ring(img,color):
    d=ImageDraw.Draw(img)
    d.ellipse([60,60,S-60,S-60],outline=color+(255,),width=46)
    d.ellipse([130,130,S-130,S-130],outline=(255,255,255,60),width=10)
def text(img,txt,y,size,fill,stroke=(20,10,25),sw=28,font=FONTX):
    f=ImageFont.truetype(font,size); d=ImageDraw.Draw(img)
    w=d.textlength(txt,font=f)
    d.text(((S-w)/2,y),txt,font=f,fill=fill,stroke_width=sw,stroke_fill=stroke)
def ribbon(img,y,txt,col,size=120):
    d=ImageDraw.Draw(img); f=ImageFont.truetype(FONTX,size)
    w=d.textlength(txt,font=f)+140; h=size+70; x0=(S-w)/2
    d.rounded_rectangle([x0,y,x0+w,y+h],radius=h/2,fill=col+(255,),outline=(255,255,255,255),width=12)
    d.text(((S-(w-140))/2,y+22),txt,font=f,fill=(255,255,255),stroke_width=8,stroke_fill=(30,15,10))
def vignette(img):
    m=Image.new('L',(S,S),0); d=ImageDraw.Draw(m); d.ellipse([-200,-200,S+200,S+200],fill=255)
    m=m.filter(ImageFilter.GaussianBlur(200)); dark=Image.new('RGBA',(S,S),(0,0,0,255))
    inv=ImageChops.invert(m); dark.putalpha(inv.point(lambda v:int(v*0.7)))
    img.alpha_composite(dark)
def save(img,name):
    img.convert('RGB').resize((512,512),Image.LANCZOS).save(OUT+name)

# ---------- VIP
img=radial((120,40,150),(15,5,25))
glow(img,lambda d,c:d.ellipse([500,350,1550,1400],fill=c),(255,190,40,200),160)
sparkles(img,(255,230,140),70,1)
gold=(255,200,50); dk=(120,70,0)
d=ImageDraw.Draw(img)
crown=[(560,900),(600,420),(820,680),(1024,330),(1228,680),(1448,420),(1488,900)]
d.polygon(crown,fill=dk); 
crown2=[(590,870),(625,470),(830,720),(1024,390),(1218,720),(1423,470),(1458,870)]
d.polygon(crown2,fill=gold)
d.polygon([(625,470),(830,720),(1024,390),(1024,520),(830,800),(640,620)],fill=(255,230,120))
d.rounded_rectangle([560,860,1488,990],radius=30,fill=(230,160,20),outline=dk,width=18)
for x,c in [(700,(255,60,90)),(1024,(60,200,255)),(1348,(120,255,120))]:
    d.ellipse([x-48,877,x+48,973],fill=c,outline=(255,255,255),width=8)
for x,y in [(600,420),(1024,330),(1448,420)]:
    d.ellipse([x-55,y-55,x+55,y+55],fill=(255,240,180),outline=dk,width=14)
text(img,"VIP",1000,520,(255,215,70),stroke=(70,30,0),sw=34)
ribbon(img,1560,"x2 TICKETS",(200,40,120))
ring(img,gold); vignette(img); ring(img,gold); save(img,'vip.png')

# ---------- PRO FLASHLIGHT
img=radial((20,40,90),(3,6,18),center=(0.5,0.5))
d=ImageDraw.Draw(img)
# beam cone from bottom-left to upper-right
beam=Image.new('RGBA',(S,S),(0,0,0,0)); bd=ImageDraw.Draw(beam)
ox,oy=760,1180
bd.polygon([(ox,oy),(1850,300),(1900,1000)],fill=(255,240,170,150))
beam=beam.filter(ImageFilter.GaussianBlur(40))
cm=Image.new('L',(S,S),0); ImageDraw.Draw(cm).ellipse([110,110,S-110,S-110],fill=255)
beam.putalpha(ImageChops.multiply(beam.getchannel('A'),cm)); img.alpha_composite(beam)
beam2=Image.new('RGBA',(S,S),(0,0,0,0)); bd=ImageDraw.Draw(beam2)
bd.polygon([(ox,oy),(1780,450),(1800,850)],fill=(255,255,230,140))
beam2=beam2.filter(ImageFilter.GaussianBlur(25)); beam2.putalpha(ImageChops.multiply(beam2.getchannel('A'),cm)); img.alpha_composite(beam2)
# frozen eyes in the beam
for ex in (1430,1600):
    glow(img,lambda d,c,ex=ex:d.ellipse([ex-70,600-70,ex+70,600+70],fill=c),(0,200,255,255),40)
    d=ImageDraw.Draw(img)
    d.ellipse([ex-60,540,ex+60,660],fill=(250,250,245)); d.ellipse([ex-26,574,ex+26,626],fill=(0,170,255))
# flashlight body (rotated)
fl=Image.new('RGBA',(S,S),(0,0,0,0)); fd=ImageDraw.Draw(fl)
cx,cy=1024,1024
fd.rounded_rectangle([cx-520,cy-110,cx+80,cy+110],radius=60,fill=(55,60,75),outline=(15,15,20),width=22)
for i in range(5): fd.rectangle([cx-440+i*90,cy-110,cx-410+i*90,cy+110],fill=(35,38,48))
fd.polygon([(cx+60,cy-130),(cx+330,cy-250),(cx+330,cy+250),(cx+60,cy+130)],fill=(240,180,30),outline=(15,15,20))
fd.line([(cx+60,cy-130),(cx+330,cy-250),(cx+330,cy+250),(cx+60,cy+130),(cx+60,cy-130)],fill=(15,15,20),width=22)
fd.ellipse([cx+280,cy-250,cx+380,cy+250],fill=(255,255,220),outline=(15,15,20),width=18)
fd.rounded_rectangle([cx-260,cy-150,cx-150,cy-100],radius=15,fill=(255,70,70))
fl=fl.rotate(37,center=(cx,cy),resample=Image.BICUBIC,translate=(-200,20))
img.alpha_composite(fl)
sparkles(img,(255,245,200),30,2)
text(img,"PRO",1250,330,(255,215,60),stroke=(20,15,40),sw=30)
ribbon(img,1660,"+70% BATTERY",(30,140,230),size=105)
ring(img,(255,200,50)); vignette(img); ring(img,(255,200,50)); save(img,'pro_flashlight.png')

# ---------- LUCKY CHARM
img=radial((30,150,70),(3,25,10))
glow(img,lambda d,c:d.ellipse([480,280,1570,1370],fill=c),(140,255,120,170),170)
sparkles(img,(220,255,200),80,3)
d=ImageDraw.Draw(img)
cx,cy=1024,760
def heartpts(ang,scale,dist):
    ux,uy=math.cos(ang),math.sin(ang); px,py=-uy,ux
    pts=[]
    for i in range(160):
        t=i/160*2*math.pi
        x=16*math.sin(t)**3; y=13*math.cos(t)-5*math.cos(2*t)-2*math.cos(3*t)-math.cos(4*t)
        r=dist+(y+17)*scale
        pts.append((cx+ux*r+px*x*scale, cy+uy*r+py*x*scale))
    return pts
d.line([(cx,cy+100),(cx+120,cy+520),(cx+60,cy+700)],fill=(20,90,30),width=70,joint='curve')
for a in range(4):
    ang=math.radians(45+90*a)
    d.polygon(heartpts(ang,15.5,10),fill=(10,60,20))
for a in range(4):
    ang=math.radians(45+90*a)
    d.polygon(heartpts(ang,13.5,40),fill=(70,215,90))
    d.polygon(heartpts(ang,6.5,150),fill=(120,245,130))
d.ellipse([cx-85,cy-85,cx+85,cy+85],fill=(255,210,60),outline=(120,70,0),width=16)
text(img,"LUCKY",1330,330,(255,225,90),stroke=(10,50,15),sw=26)
ribbon(img,1700,"x2 EPIC ODDS",(150,60,220),size=105)
ring(img,(120,255,120)); vignette(img); ring(img,(120,255,120)); save(img,'lucky_charm.png')
print('ok')
