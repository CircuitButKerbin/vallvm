_T=true
function _F(...)return _S.format(...) end
local a={init=false,S={},B={},K=1,P="",G={},FN={},R={}}local function b(c)local function d(e,f)local f,g=f or":",{}e:gsub(_F("([^%s]+)",f),function(h)g[#g+1]=h end)return g end
_ENV.newT=function () return {} end
_ENV.State=function () return a end
_ENV.len=function (t) return #t end
_ENV.concat=function(a,b) return a..b end
if c:match("%.")then local i=d(c,"%.")local j=_ENV
for k=1,#i do j=j[i[k]]if not j then return nil end end
return j end
return _ENV[c]end
i,o=input,output
iB=i.getBool
iN=i.getNumber
oN=o.setNumber
oB=o.setBool
_L=_T
ER=""_E=function(l)_L=false
ER=l end
_V=0
_S=string
_T=table
_TR=_T.remove
_SF=_S.find
_SU=_S.unpack
_B=_S.byte
_C=_S.char
_D=screen.drawText
local m,n,o,p,q=nil,0x3F,0,0,0
local function r(s)return s==1 and _T end
function tI(t)if t then return 1 end
return 0 end
function onTick()if m and _L then if q>0 then EB(a.P,a,"onTick")else EB(a.P,a,"init")q=1 end elseif not m and _L then if p==0 then p=p+1
return end
for k=0,31 do oB(k+1,r(o>>k&1))end
local h=""local u=0
for k=0,31 do u=u|(tI(iB(k+1))<<k)end
_V=u
for k=0,3 do h=h.._C(u>>k*8&255)end
a.P=a.P..h
if n==o then m=_T end
o=o+1
p=p+1 end end
function onDraw()if m and _L then EB(a.P,a,"onDraw")elseif _L and not m then _D(8,8,_F("%%%.2f | %08X",o/n*100,_V))else _D(0,32*5-6,ER)for k=0,15 do _D(0,k*6,_F("%1X0 |",k))for v=0,15 do _D(k*12+20,v*6,_F("%02X",a.P:byte(k+v*8)or 0))end end end end
function EB(w,x,y)function _X(p,z)for k=1,z do _TR(p,#p)end end
function S(...)for k,u in ipairs({...})do x.S[#x.S+1]=u end end
function RF(w)local A={}local k=0
while _SF(w,_C(42),k)do local B=_SF(w,_C(42),k)+1
k=B
local _,p,C,D=PO(w,k)k=k+C
A[D]={pt=k}end
x.FN=A end
function PO(w,E)local F=_B(w,E)local G=F&31
if G==0 then return nil,0,1 end
if F&64==1 then return x.B[F&31],9,1 end
if G<=3 then return _SU(G==3 and"f"or _F("i%d",G*2),w,E+1),G,G==1 and 3 or 5 end
if G==5 then local C=_SU("i2",w,E+1)return _S.sub(w,E+3,E+2+C),5,C+3 end
if G==8 then local e=_SU("z",w,E+1)return x.G[e],8,#e+2,e end end
function WO(u,p,_,H)if p==8 then x.G[H]=u
return end
if p==9 then x.B[H]=u
return end end
function EI(w,E,I)
local J=_B(w,E)if J==1 then local u,p,C=PO(w,E+1)S(u)x.K=E+1+C elseif J==2 then local u,p,C,H=PO(w,E+1)WO(_TR(x.S),p,C,H)x.K=E+1+C elseif J==11 then x.S[#x.S]=~x.S[#x.S]x.K=E+1 elseif 3<=J and J<=0x15 then local K,t=x.S[#x.S],x.S[#x.S-1]_X(x.S,2)if J==3 then S(K+t)elseif J==4 then S(K-t)elseif J==5 then S(K*t)elseif J==6 then S(K/t)elseif J==7 then S(K%t)elseif J==8 then S(K&t)elseif J==9 then S(K|t)elseif J==10 then S(K~t)elseif J==12 then S(K<<t)elseif J==13 then S(K>>t)elseif J==16 then S(K==t)elseif J==17 then S(K~=t)elseif J==18 then S(K<t)elseif J==19 then S(K>t)elseif J==20 then S(K<=t)elseif J==21 then S(K>=t)end
x.K=E+1 elseif J==22 then local u,p,C,H=PO(w,E+1)S(u)x.K=E+C+1 elseif J==23 then local u,p,C,H=PO(w,E+1)WO(x.S[#x.S],p,_,H)x.K=E+C+1 elseif J==24 then local L,M,C,N=PO(w,E+1)local O,P,Q,R=PO(w,E+1+C)WO(O,M,Q,N)x.K=E+1+C+Q elseif J==32 then local _,p,C,H=PO(w,E+1)x.R[#x.R+1]=x.K
x.K=x.FN[H].pt elseif J==33 then if I then return _T end
x.K=x.R[#x.R]_X(x.R,1)elseif J>=34 and J<=39 then local u,p,C=PO(w,E+1)local T=_TR(x.S,#x.S)if type(T)~="boolean"then T=T~=0 end
local U=J==34 or J==37 or(J==35 or J==38)and T or(J==36 or J==39)and not T
if U then x.K=J>=37 and x.K+u or u else x.K=x.K+C+1 end elseif J==25 then local K,t=x.S[#x.S],x.S[#x.S-1]x.S[#x.S]=t
x.S[#x.S-1]=K
x.K=E+1 elseif J==26 then x.S[#x.S+1]=x.S[#x.S]x.K=E+1 elseif J==27 then _X(x.S,1)x.K=E+1 elseif J==28 then x.S[#x.S+1]=x.S[#x.S-1]elseif J==40 then local _,p,C,V=PO(w,E+1)local W=b(V)local X,p,Q=PO(w,E+1+C)local Y={}for k=1,X do Y[k]=x.S[#x.S-X+k]end
_X(x.S,X)local Z=_T.pack(W(_T.unpack(Y)))local a0,p,a1=PO(w,E+1+C+Q)for k=1,a0 do S(Z[k])end
x.K=E+1+C+Q+a1 elseif J==41 then return _T elseif J==49 then x.K=E+1 else _E(_F("%02X",J or 0))return _T end end
if not x.init then RF(w)x.init=_T end
if y then if x.FN[y]then x.K=x.FN[y].pt else end end
while _T do local a2=_B(w,x.K)local a3
a3=EI(w,x.K,_T)if a3 then
break end end end