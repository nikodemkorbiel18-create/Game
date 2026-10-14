import re, json, sys
chunks = """Every shipping container|on Earth has the same|steel corners.|In 1937,|trucker Malcolm McLean|waited all day|at a New Jersey dock,|as workers unloaded|his cotton bales,|one by one.|So, he wondered...|why not lift the whole truck|onto the ship?|But, wheels and cabs|wasted precious space.|So, he took the boxes|off the wheels,|and in 1956,|an old tanker sailed|with fifty-eight of them.|Loading costs fell|from nearly six dollars a ton,|to sixteen cents.|But, every company|built different boxes,|with different hooks.|A crane in one port|couldn't lift a box|from another.|So, engineer|Keith Tantlinger|designed a steel corner|with an oval hole,|and a twistlock|that turns,|and locks.|But, rivals|would have to pay|to use it.|So, McLean|gave the patents away,|for free.|Now, one crane|could lift any box,|onto any ship,|truck,|or train.|Today, almost everything|you own|once rode in a steel box,|locked at the same|steel corners.""".split("|")
spoken = {"1937":"nineteen thirty seven","1956":"nineteen fifty six"}
def syl(t):
    for k,v in spoken.items(): t=t.replace(k,v)
    n=0
    for w in re.findall(r"[a-zA-Z']+",t):
        w=w.lower(); g=len(re.findall(r"[aeiouy]+",w))
        if w.endswith('e') and g>1 and not w.endswith('le'): g-=1
        n+=max(1,g)
    return n
S=[syl(c) for c in chunks]
P=[tuple(map(float,l.split())) for l in open('pauses.txt')]
END=65.15
# boundary candidates: chunk end with punctuation is "strong"
strong=[bool(re.search(r"[,.?]$|\.\.\.$",c)) for c in chunks]
# speech intervals
starts=[0.0]+[e for s,e in P]; ends=[s for s,e in P]+[END]
# skip leading silence
import math
speech=sum(e-s for s,e in zip(starts,ends))
rate=speech/sum(S)
# DP: assign chunk i..k to speech interval j (each interval holds >=1 consecutive chunks), all intervals used
n=len(chunks); m=len(starts)
INF=1e18
dp=[[INF]*(m+1) for _ in range(n+1)]; bk={}
dp[0][0]=0
cum=[0]
for s in S: cum.append(cum[-1]+s)
for i in range(n+1):
    for j in range(m):
        if dp[i][j]>=INF: continue
        d=ends[j]-starts[j]
        for k in range(i+1,n+1):
            exp=(cum[k]-cum[i])*rate
            c=(d-exp)**2/(exp+0.3)
            if k<n and not strong[k-1]: c+=2.0  # pause at weak boundary
            if dp[i][j]+c<dp[k][j+1]:
                dp[k][j+1]=dp[i][j]+c; bk[(k,j+1)]=i
            if exp>d*3: break
i,j=n,m; segs=[]
while j>0:
    pi=bk[(i,j)]; segs.append((pi,i,j-1)); i,j=pi,j-1
segs.reverse()
out=[]
for a,b,j in segs:
    t0,t1=starts[j],ends[j]; tot=cum[b]-cum[a]; t=t0
    for k in range(a,b):
        dur=(t1-t0)*S[k]/tot
        out.append([chunks[k],round(t,2),round(t+dur,2)]); t+=dur
for o in out: print(o)
json.dump(out,open('caps.json','w'))
