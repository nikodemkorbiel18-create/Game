import numpy as np, wave
sr=44100; dur=66.5; n=int(sr*dur); out=np.zeros(n)
bpm=84; beat=60/bpm
f=lambda m: 440*2**((m-69)/12)
chords=[[60,64,67,71],[57,60,64,67],[53,57,60,64],[55,59,62,67]]  # Cmaj7 Am7 Fmaj7 G
def pluck(t0,m,amp,dec=1.6):
    i0=int(t0*sr); L=int(sr*dec*2.5); i1=min(n,i0+L); t=np.arange(i1-i0)/sr
    fr=f(m); env=np.exp(-t/dec*2.2)*(1-np.exp(-t*400))
    s=np.sin(2*np.pi*fr*t)+0.35*np.sin(4*np.pi*fr*t)*np.exp(-t*3)+0.12*np.sin(6*np.pi*fr*t)*np.exp(-t*6)
    out[i0:i1]+=amp*env*s
def pad(t0,ms,len_,amp):
    i0=int(t0*sr); i1=min(n,i0+int(len_*sr)); t=np.arange(i1-i0)/sr
    env=np.minimum(1,t/1.2)*np.minimum(1,(len_-t)/1.2)
    s=sum(np.sin(2*np.pi*f(m-12)*t)+0.5*np.sin(2*np.pi*f(m-12)*1.003*t) for m in ms)
    out[i0:i1]+=amp*env*s/len(ms)
bar=4*beat; t=0; k=0
arp=[0,2,1,3,2,1,3,2]
mel=[[72,None,74,None],[72,None,69,None],[69,None,72,None],[71,None,74,None]]
while t<dur:
    c=chords[k%4]
    pad(t,c,bar+1.0,0.18)
    pluck(t,c[0]-12,0.22,2.2)
    for j,a in enumerate(arp):
        pluck(t+j*beat/2,c[a]+12,0.07,0.9)
    if (k//4)%2==1:
        for j,m in enumerate(mel[k%4]):
            if m: pluck(t+j*beat,m+12,0.09,1.2)
    t+=bar; k+=1
# fade
fi=int(0.5*sr); fo=int(1.5*sr)
out[:fi]*=np.linspace(0,1,fi); out[-fo:]*=np.linspace(1,0,fo)
out/=np.abs(out).max()*1.12
# simple stereo widen with tiny delay
l=out; r=np.roll(out,int(0.012*sr))
st=(np.stack([l,r],1)*32767).astype(np.int16)
w=wave.open('music.wav','wb'); w.setnchannels(2); w.setsampwidth(2); w.setframerate(sr); w.writeframes(st.tobytes()); w.close()
print('ok')
