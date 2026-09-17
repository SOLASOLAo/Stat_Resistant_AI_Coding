"""Offline numerical model of PLC Welford add/remove, checked against batch statistics.
This verifies the arithmetic and process boundaries, not execution on a PLC runtime.
"""
from collections import deque
from pathlib import Path
from statistics import stdev
from math import sin, sqrt, isclose, isfinite
import struct

class Rolling:
    def __init__(self, window=1000, limit=30, threshold=2500):
        self.window,self.limit,self.threshold=window,limit,threshold
        self.q=deque();self.mean=self.m2=self.three=0.0;self.full=self.qualified=False
    def sample(self,t,x,good=True):
        if not good or not isfinite(x) or x<=self.threshold:
            self.q.clear();self.mean=self.m2=self.three=0.0;self.full=self.qualified=False;return False
        while len(self.q)>1 and t-self.q[1][0]>=self.window:
            _,old=self.q.popleft();n=len(self.q);before=self.mean
            self.mean=((n+1)*self.mean-old)/n
            self.m2-=(old-before)*(old-self.mean)
        n=len(self.q)+1;delta=x-self.mean;self.mean+=delta/n
        self.m2=max(0,self.m2+delta*(x-self.mean));self.q.append((t,x))
        self.three=3*sqrt(self.m2/(n-1)) if n>1 else 0
        self.full=n>1 and t-self.q[0][0]>=self.window
        self.qualified=self.full and self.three<self.limit
        return self.qualified

def f32(n):return struct.unpack('f',struct.pack('f',n))[0]
checks=0
for window in (12,500,1000,3500,60000):
    r=Rolling(window)
    for i in range(23000):
        t=i*6+(i%2)  # 5/7 ms clock rounding, one sample per MainTask scan
        x=f32(3000+8*sin(i*.31)+3*sin(i*.07));r.sample(t,x)
        if i%137==0 and len(r.q)>1:
            batch=3*stdev(x for _,x in r.q)
            assert isclose(r.three,batch,rel_tol=1e-7,abs_tol=1e-7)
            assert len(r.q)<=10002
            checks+=1
r=Rolling();assert not r.sample(0,3000)
for t in range(6,1000,6):assert not r.sample(t,3000)
assert r.sample(1002,3000) and len(r.q)==168 and r.three==0;checks+=1
assert not r.sample(1008,2500) and len(r.q)==0;checks+=1
assert not r.sample(1014,3000);assert not r.sample(2010,3000);assert r.sample(2016,3000);checks+=1
r=Rolling(12,3)
for t,x in ((0,3000),(6,3001),(12,3002)):r.sample(t,x)
assert r.three==3 and not r.qualified;r.limit=3.0001;assert r.three<r.limit;checks+=1
for bad in (float('nan'),float('inf'),float('-inf')):
    assert not r.sample(18,bad) and not r.full;checks+=1
# Deliberate alternating force must not qualify even above the threshold.
r=Rolling(1000,30)
for i in range(2000):assert not r.sample(i*6,2900 if i%2 else 3100)
checks+=1
# No HMI data retention in this model: statistics continue beyond trace capacity.
r=Rolling()
for i in range(12000):r.sample(i*6,3000)
assert r.qualified and r.full;checks+=1
for period in (1, 6, 10):
    r = Rolling(1000, 30)
    full_at = ((1000 + period - 1) // period) * period
    for t in range(0, full_at + period, period):
        qualified = r.sample(t, f32(3000 + sin(t / 30)))
        assert qualified == (t >= 1000)
    assert isclose(r.three, 3 * stdev(x for _, x in r.q), rel_tol=1e-7)
    assert len(r.q) == full_at // period + 1
    checks += 1
print(f'PASS: {checks} numerical/reference and boundary checks; offline model only')
