using System;

namespace Bpp.ForceTrace
{
    // Versioned whole-array snapshots. PLC data, timestamps and verdicts are authoritative.
    public sealed class ForceTraceFrames
    {
        private readonly object gate = new object();
        private readonly ForceTraceStore store;
        private uint boot, cycle, sequence;
        private long lastFreshMs;
        private bool connected;
        public bool Connected { get { lock (gate) return connected; } }
        public ForceTraceFrames(ForceTraceStore target) { store=target; }
        public void ObserveStatistics(object value, bool good, long now)
        {
            lock(gate)
            {
                StatisticsSnapshot next;
                if(!good || !TryStatistics(value,out next)) { DisconnectCore(); return; }
                if(connected && next.BootId==boot)
                {
                    uint advance=unchecked(next.Sequence-sequence);
                    if(advance==0 || advance>Int32.MaxValue) { CheckTimeoutCore(now); return; }
                }
                connected=true; boot=next.BootId; cycle=next.Cycle; sequence=next.Sequence; lastFreshMs=now;
                store.Accept(next);
            }
        }
        public void ObserveTrace(object value,bool good,TracePosition expected,DateTimeOffset received)
        {
            lock(gate)
            {
                TraceSnapshot next;
                if(!good || !TryTrace(value,received,out next) || next.Position!=expected)
                {store.ClearTrace(expected);return;}
                TraceSnapshot previous=store.Snapshot(expected);
                if(previous!=null && previous.BootId==next.BootId && previous.Cycle==next.Cycle && previous.Acquisition==next.Acquisition)
                {
                    uint advance=unchecked(next.Sequence-previous.Sequence);
                    if(advance>Int32.MaxValue || next.Samples.Count<previous.Samples.Count) return;
                    if(previous.EndReason!=TraceEndReason.Running && next.EndReason==TraceEndReason.Running) return;
                }
                store.Accept(next);
            }
        }
        public void CheckTimeout(long now) {lock(gate) CheckTimeoutCore(now);}
        private void CheckTimeoutCore(long now) {if(connected && now-lastFreshMs>500) DisconnectCore();}
        public void Disconnect() {lock(gate) DisconnectCore();}
        private void DisconnectCore() {connected=false;store.Clear();}
        public static double Float(uint bits) {return BitConverter.ToSingle(BitConverter.GetBytes(bits),0);}
        public static bool Finite(double value) {return !Double.IsNaN(value) && !Double.IsInfinity(value);}
        private static bool Words(object value,int length,out uint[] words)
        {
            words=null; Array a=value as Array;
            if(a==null || a.Rank!=1 || a.Length!=length) return false;
            uint[] w=new uint[length]; int lower=a.GetLowerBound(0);
            for(int i=0;i<length;i++)
            {
                object e=a.GetValue(lower+i);
                if(e is uint) w[i]=(uint)e;
                else if(e is int) w[i]=unchecked((uint)(int)e);
                else return false;
            }
            if(w[0]==0 || w[1]!=2 || w[0]!=w[length-1]) return false;
            words=w;return true;
        }
        private static uint Hash(uint hash,uint value) {return unchecked((hash^value)*16777619);}
        public static bool TryTrace(object value,DateTimeOffset received,out TraceSnapshot result)
        {
            result=null;uint[] w;
            if(!Words(value,30036,out w) || w[5]<1 || w[5]>3 || w[6]>5 || w[7]>10001 || w[8]>1 || w[16]!=6) return false;
            uint count=w[7], hash=2166136261;
            for(int i=32;i<32+count*3;i++) hash=Hash(hash,w[i]);
            for(int i=0;i<31;i++) hash=Hash(hash,w[i]);
            if(hash!=w[31] || w[17]<count || w[9]>w[17] || (w[9]==0 && w[10]!=0)) return false;
            if(w[6]==0)
            { if(count!=0 || w[4]!=0) return false; }
            else if(w[3]==0 || w[4]==0 || !Parameters(w[12],w[13],w[14],w[15])) return false;
            if(w[9]>0 && w[10]>w[11]) return false;
            ForceSample[] samples=new ForceSample[count]; uint previous=0;
            for(int i=0;i<count;i++)
            {
                int p=32+i*3; double force=Float(w[p+1]); uint time=w[p],quality=w[p+2];
                if(quality>2 || (quality==1 && !Finite(force)) || time>60000 || time>w[11] || (i>0 && time<=previous)) return false;
                if(i==0 && time!=0) return false;
                samples[i]=new ForceSample((uint)i+1,time,force,(SampleQuality)quality); previous=time;
            }
            if(w[9]>0 && w[9]<=count && samples[w[9]-1].ElapsedMs!=w[10]) return false;
            result=new TraceSnapshot(w,samples,received);return true;
        }
        private static bool Parameters(uint threshold,uint limit,uint window,uint timeout)
        {return Finite(Float(threshold)) && Float(threshold)>=0 && Finite(Float(limit)) && Float(limit)>0 && window>0 && window<=60000 && timeout>window;}
        public static bool TryStatistics(object value,out StatisticsSnapshot result)
        {
            result=null;uint[] w;
            if(!Words(value,210,out w) || w[4]>3 || w[6]!=20 || w[7]!=6) return false;
            uint hash=2166136261;
            for(int i=0;i<208;i++)hash=Hash(hash,w[i]);
            if(hash!=w[208])return false;
            PositionStatistics[] positions=new PositionStatistics[3];
            for(int n=0;n<3;n++)
            {
                int b=16+n*64;
                if(w[b+1]==0)
                {
                    for(int i=0;i<64;i++)if(w[b+i]!=0)return false;
                    positions[n]=new PositionStatistics(w,b,n+1);continue;
                }
                if(w[b]!=(uint)n+1 || w[b+2]<1 || w[b+2]>5 || w[b+3]>10002 || w[b+4]>31 || w[b+22]!=20 || w[b+44]!=6 ||
                   !Parameters(w[b+11],w[b+12],w[b+13],w[b+14]) || w[b+16]>w[b+17] || w[b+17]>w[b+15])return false;
                for(int i=6;i<=12;i++)if(!Finite(Float(w[b+i])))return false;
                if(!Finite(Float(w[b+20])) || !Finite(Float(w[b+21])) || Float(w[b+21])<0 || Float(w[b+7])<0 || Float(w[b+8])<0)return false;
                if((w[b+4]&1)!=0 && !Finite(Float(w[b+5])))return false;
                ulong sum=0;for(int i=0;i<20;i++)sum+=w[b+23+i];
                if(sum!=w[b+3] || (w[b+3]>0 && Float(w[b+9])>Float(w[b+10])))return false;
                // Stable is the PLC LREAL verdict. Display REALs may round a value
                // just below the limit up to equality; never re-grade that verdict.
                if((w[b+4]&4)!=0 && ((w[b+4]&3)!=3 || (w[b+4]&16)!=0 || w[b+3]<2))return false;
                positions[n]=new PositionStatistics(w,b,n+1);
            }
            result=new StatisticsSnapshot(w,positions);return true;
        }
    }
}
