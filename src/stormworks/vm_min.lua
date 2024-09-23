local a={ticks=0,init=false,stk={},reg={},pc=1,pg="",globals={},fns={},RAS={},cycles=0}local function b(c)local function d(e,f)local f,g=f or":",{}e:gsub(_S.format("([^%s]+)",f),function(h)g[#g+1]=h end)return g end
if c:match("%.")then local i=d(c,"%.")local j=_ENV
for k=1,#i do j=j[i[k]]if not j then return nil end end
return j end
return _ENV[c]end
iB=input.getBool
iN=input.getNumber
oN=output.setNumber
oB=output.setBool
live=true
ER=""_E=function(l)live=false
ER=l end
_V=0
_S=string
_T=table
_D=screen.drawText
local m
local n=0x3F
local o=0
local p=0
local q=0
local function r(s)return s==1 and true end
function tI(t)if t then return 1 end
return 0 end
function fmt(...)return _S.format(...)end
function onTick()if m and live then if q>0 then EB(a.pg,a,"onTick")else EB(a.pg,a,"init")q=1 end elseif not m and live then if p==0 then p=p+1
return end
for k=0,31 do oB(k+1,r(o>>k&1))end
local h=""local u=0
for k=0,31 do u=u|(tI(iB(k+1))<<k)end
_V=u
for k=0,3 do h=h.._S.char(u>>k*8&0xFF)end
a.pg=a.pg..h
if n==o then m=true end
o=o+1
p=p+1 end end
function onDraw()if m and live then EB(a.pg,a,"onDraw")elseif live and not m then _D(8,8,fmt("Loading %%%.2f | %08X",o/n*100,_V))else _D(0,32*5-6,fmt("DIED | %s",ER))for k=0,15 do _D(0,k*6,fmt("%1X0 |",k))for v=0,15 do _D(k*12+20,v*6,fmt("%02X",a.pg:byte(k+v*8)or 0))end end end end
function EB(w,x,y)function cut(p,z)for k=1,z do _T.remove(p,#p)end end
function pull(z,...)return _T.unpack(_T.pack(...),1,z)end
function S(...)for k,u in ipairs({...})do x.stk[#x.stk+1]=u end end
function RF(w)local A={}local k=0
while _S.find(w,_S.char(0x2A),k)do local B=_S.find(w,_S.char(0x2A),k)+1
k=B
local _,p,C,D=PO(w,k)k=k+C
A[D]={pointer=k}end
x.fns=A end
function PO(w,E)local F=_S.byte(w,E)local G=F&0x1F
if G==0 then return nil,0,1 end
if F&0x40==1 then return x.reg[F&0x1F],9,1 end
if G<=3 then return _S.unpack(G==3 and"f"or fmt("i%d",G*2),w,E+1),G,G==1 and 3 or 5 end
if G==5 then local C=_S.unpack("i2",w,E+1)return _S.sub(w,E+3,E+2+C),5,C+3 end
if G==8 then local e=_S.unpack("z",w,E+1)return x.globals[e],8,#e+2,e end end
function WO(u,p,_,H)if p==8 then x.globals[H]=u
return end
if p==9 then x.reg[H]=u
return end end
function EI(w,E,I)a.cycles=a.cycles+1
local J=_S.byte(w,E)if J==1 then local u,p,C=PO(w,E+1)S(u)x.pc=E+1+C elseif J==2 then local u,p,C,H=PO(w,E+1)WO(_T.remove(x.stk),p,C,H)x.pc=E+1+C elseif J==11 then x.stk[#x.stk]=~x.stk[#x.stk]x.pc=E+1 elseif 3<=J and J<=0x15 then local K,t=x.stk[#x.stk],x.stk[#x.stk-1]cut(x.stk,2)if J==3 then S(K+t)elseif J==4 then S(K-t)elseif J==5 then S(K*t)elseif J==6 then S(K/t)elseif J==7 then S(K%t)elseif J==8 then S(K&t)elseif J==9 then S(K|t)elseif J==10 then S(K~t)elseif J==12 then S(K<<t)elseif J==13 then S(K>>t)elseif J==16 then S(K==t)elseif J==17 then S(K~=t)elseif J==18 then S(K<t)elseif J==19 then S(K>t)elseif J==20 then S(K<=t)elseif J==21 then S(K>=t)end
x.pc=E+1 elseif J==22 then local u,p,C,H=PO(w,E+1)S(u)x.pc=E+C+1 elseif J==23 then local u,p,C,H=PO(w,E+1)WO(_T.remove(x.stk,#x.stk),p,_,H)x.pc=E+C+1 elseif J==24 then local L,M,C,N=PO(w,E+1)local O,P,Q,R=PO(w,E+1+C)WO(O,M,Q,N)x.pc=E+1+C+Q elseif J==32 then local _,p,C,H=PO(w,E+1)x.RAS[#x.RAS+1]=x.pc
x.pc=x.fns[H].pointer elseif J==33 then if I then return true end
x.pc=x.RAS[#x.RAS]cut(x.RAS,1)elseif J>=34 and J<=39 then local u,p,C=PO(w,E+1)local T=_T.remove(x.stk,#x.stk)if type(T)~="boolean"then T=T~=0 end
local U=J==34 or J==37 or(J==35 or J==38)and T or(J==36 or J==39)and not T
cut(x.stk,1)if U then x.pc=J>=37 and x.pc+u or u else x.pc=x.pc+C+1 end elseif J==40 then local _,p,C,V=PO(w,E+1)local W=b(V)local X,p,Q=PO(w,E+1+C)local Y={}for k=1,X do Y[k]=x.stk[#x.stk-X+k]end
cut(x.stk,X)local Z=_T.pack(W(_T.unpack(Y)))local a0,p,a1=PO(w,E+1+C+Q)for k=1,a0 do S(Z[k])end
x.pc=E+1+C+Q+a1 elseif J==41 then return true else _E(fmt("unkop: %02X",J or 0))return true end end
if not x.init then RF(w)x.init=true end
if y then if x.fns[y]then x.pc=x.fns[y].pointer else end end
while true do local a2=_S.byte(w,x.pc)local a3
a3=EI(w,x.pc,true)if a3 then x.ticks=x.ticks+1
break end end end