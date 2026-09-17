using System;
using System.IO;
using System.Linq;
using ForceTrace.Hmi;

public static class ForceTraceFixture
{
    public static uint Bits(double n){return BitConverter.ToUInt32(BitConverter.GetBytes((float)n),0);}
    public static void TraceHash(uint[] w)
    {uint h=2166136261;for(int i=32;i<32+w[7]*3;i++)h=unchecked((h^w[i])*16777619);for(int i=0;i<31;i++)h=unchecked((h^w[i])*16777619);w[31]=h;w[30035]=w[0];}
    public static void StatsHash(uint[] w)
    {uint h=2166136261;for(int i=0;i<208;i++)h=unchecked((h^w[i])*16777619);w[208]=h;w[209]=w[0];}
    public static uint[] Trace(uint cycle=1,uint pos=1,uint state=2,int count=2001,uint stable=668,uint period=6)
    {
        uint[] w=new uint[30036];w[0]=10;w[1]=2;w[2]=42;w[3]=cycle;w[4]=pos;w[5]=pos;w[6]=state;w[7]=(uint)count;
        w[9]=stable;w[10]=stable==0?0:(stable-1)*period;w[11]=(uint)(count-1)*period;w[12]=Bits(2500);w[13]=Bits(30);w[14]=1000;w[15]=10000;w[16]=period;w[17]=(uint)count;
        for(int i=0;i<count;i++)
        {double t=i*period/1000.0;double f=t<3?10+2900*t/3:t<9?2910+8*Math.Sin(20*t):Math.Max(10,2910*(12-t)/3);int b=32+i*3;w[b]=(uint)i*period;w[b+1]=Bits(f);w[b+2]=1;}
        TraceHash(w);return w;
    }
    public static uint[] Statistics(uint cycle=1,uint pos=1,uint state=2,bool constant=false)
    {
        uint[] w=new uint[210];w[0]=10;w[1]=2;w[2]=42;w[3]=cycle;w[4]=pos;w[5]=12000;w[6]=20;w[7]=6;
        int b=16+((int)pos-1)*64;w[b]=pos;w[b+1]=pos;w[b+2]=state;w[b+3]=168;w[b+4]=state==1?7u:15u;
        double[] a=Enumerable.Range(0,168).Select(i=>constant?2910.0:(double)(float)(2910+8*Math.Sin(i*0.12))).ToArray();
        double mean=a.Average(),sd=Math.Sqrt(a.Sum(x=>(x-mean)*(x-mean))/(a.Length-1)),lo=a.Min(),hi=a.Max(),width=(hi-lo)/20;
        w[b+5]=Bits(a.Last());w[b+6]=Bits(mean);w[b+7]=Bits(sd);w[b+8]=Bits(3*sd);w[b+9]=Bits(lo);w[b+10]=Bits(hi);
        w[b+11]=Bits(2500);w[b+12]=Bits(30);w[b+13]=1000;w[b+14]=10000;w[b+15]=9000;w[b+16]=7998;w[b+17]=9000;
        w[b+18]=668;w[b+19]=4002;w[b+20]=Bits(lo);w[b+21]=Bits(width);w[b+22]=20;w[b+43]=1501;w[b+44]=6;
        foreach(double x in a){int k=width==0?0:Math.Min(19,(int)((x-lo)/width));w[b+23+k]++;}
        StatsHash(w);return w;
    }
}
public static class ForceTraceFrameTests
{
    private static int checks;
    private static void Check(bool value,string name){checks++;if(!value)throw new Exception(name);}
    private static void CheckRefreshes(DateTimeOffset now)
    {
        // Every position, two cycles: growing trace, completion, partial and duplicate
        // deliveries, then a real new acquisition. No physical PLC is used here.
        for(uint position=1;position<=3;position++)
        {
            TracePosition selected=(TracePosition)position;
            var store=new ForceTraceStore();var frames=new ForceTraceFrames(store);
            for(uint cycle=1;cycle<=2;cycle++)
            {
                uint seq=cycle*100;
                var stats=ForceTraceFixture.Statistics(cycle,position,1);stats[0]=seq;ForceTraceFixture.StatsHash(stats);
                frames.ObserveStatistics(stats,true,0);
                Check(store.Snapshot(selected)==null,"new cycle never displays previous position data");
                var trace=ForceTraceFixture.Trace(cycle,position,1,100,0);trace[0]=seq;ForceTraceFixture.TraceHash(trace);
                frames.ObserveTrace(trace,true,selected,now);TraceSnapshot running=store.Snapshot(selected);
                Check(running!=null && running.Samples.Count==100,"running trace available for each position");
                var broken=(uint[])trace.Clone();broken[33]^=1;
                frames.ObserveTrace(broken,true,selected,now);
                Check(Object.ReferenceEquals(running,store.Snapshot(selected)),"bad checksum cannot interrupt running chart");
                trace=ForceTraceFixture.Trace(cycle,position,1,200,0);trace[0]=seq+1;ForceTraceFixture.TraceHash(trace);
                frames.ObserveTrace(trace,true,selected,now);
                Check(store.Snapshot(selected).Samples.Count==200,"valid newer samples still update running chart");
                trace[0]++;trace[6]=2;ForceTraceFixture.TraceHash(trace);
                frames.ObserveTrace(trace,true,selected,now);TraceSnapshot completed=store.Snapshot(selected);
                for(int refresh=0;refresh<50;refresh++)
                {
                    trace[0]++;ForceTraceFixture.TraceHash(trace);
                    broken=(uint[])trace.Clone();broken[30035]++;
                    frames.ObserveTrace(broken,true,selected,now);
                    Check(Object.ReferenceEquals(completed,store.Snapshot(selected)),"repeated torn frame keeps completed curve");
                    frames.ObserveTrace(trace,true,selected,now);
                    Check(Object.ReferenceEquals(completed,store.Snapshot(selected)),"completed publication heartbeat keeps same snapshot");
                }
                var older=ForceTraceFixture.Trace(cycle+5,position);older[0]=seq-1;ForceTraceFixture.TraceHash(older);
                frames.ObserveTrace(older,true,selected,now);
                Check(Object.ReferenceEquals(completed,store.Snapshot(selected)),"old delivery with different identity cannot displace current curve");
                var empty=new uint[30036];empty[0]=seq+80;empty[1]=2;empty[2]=42;empty[3]=cycle;empty[5]=position;empty[16]=6;ForceTraceFixture.TraceHash(empty);
                frames.ObserveTrace(empty,true,selected,now);
                Check(store.Snapshot(selected)==null,"verified empty frame really clears the curve");
            }
        }
        var bootStore=new ForceTraceStore();var bootFrames=new ForceTraceFrames(bootStore);
        var bootStats=ForceTraceFixture.Statistics();var bootTrace=ForceTraceFixture.Trace();
        bootFrames.ObserveStatistics(bootStats,true,0);bootFrames.ObserveTrace(bootTrace,true,TracePosition.Left,now);
        TraceSnapshot beforeBoot=bootStore.Snapshot(TracePosition.Left);
        bootTrace[2]=43;ForceTraceFixture.TraceHash(bootTrace);bootFrames.ObserveTrace(bootTrace,true,TracePosition.Left,now);
        Check(Object.ReferenceEquals(beforeBoot,bootStore.Snapshot(TracePosition.Left)),"trace cannot establish a different boot before statistics");
        bootStats[2]=43;ForceTraceFixture.StatsHash(bootStats);bootFrames.ObserveStatistics(bootStats,true,100);
        Check(bootStore.Snapshot(TracePosition.Left)==null,"verified new boot clears old curve");
        bootFrames.ObserveTrace(bootTrace,true,TracePosition.Left,now);
        Check(bootStore.Snapshot(TracePosition.Left).BootId==43,"retained refresh restores new boot data");
        bootFrames.ObserveTrace(ForceTraceFixture.Trace(),true,TracePosition.Left,now);
        Check(bootStore.Snapshot(TracePosition.Left).BootId==43,"old boot trace cannot erase new boot data");
        bootFrames.ObserveStatistics(bootStats,false,110);
        Check(!bootFrames.Connected && bootStore.Snapshot(TracePosition.Left)==null,"actual statistics quality loss still clears data");
    }
    public static int Main()
    {
        var now=DateTimeOffset.Parse("2026-09-15T10:00:00Z");TraceSnapshot t;StatisticsSnapshot s;
        uint[] trace=ForceTraceFixture.Trace(),stats=ForceTraceFixture.Statistics();
        Check(ForceTraceFrames.TryTrace(trace,now,out t),"valid retained trace");
        Check(t.Samples.Count==2001 && t.Samples[2000].ElapsedMs==12000,"PLC times retained");
        Check(ForceTraceFrames.TryStatistics(stats,out s),"same-window histogram");
        var p=s.Positions[0];Check(Math.Abs(Enumerable.Range(0,20).Sum(i=>p.Density(i)*p.BinWidth)-1)<1e-6,"histogram area one");
        double area=0,dx=p.Sigma*12/10000;for(int i=0;i<10000;i++)area+=p.NormalDensity(p.Mean-6*p.Sigma+(i+0.5)*dx)*dx;
        Check(Math.Abs(area-1)<1e-6,"normal density reference integrates to one");
        Check(ForceTraceFrames.TryStatistics(ForceTraceFixture.Statistics(constant:true),out s) && s.Positions[0].NormalDensity(2910)==0,"zero sigma has no divided PDF");
        var rounded=ForceTraceFixture.Statistics(state:1);rounded[24]=ForceTraceFixture.Bits(29.9999999);rounded[23]=ForceTraceFixture.Bits(29.9999999/3);ForceTraceFixture.StatsHash(rounded);
        Check(rounded[24]==rounded[28] && ForceTraceFrames.TryStatistics(rounded,out s) && s.Positions[0].Stable,"PLC LREAL verdict survives REAL display rounding at limit");
        rounded[20]=5;ForceTraceFixture.StatsHash(rounded);
        Check(!ForceTraceFrames.TryStatistics(rounded,out s),"stable still requires PLC full-window flag");
        var broken=(uint[])trace.Clone();broken[33]^=1;Check(!ForceTraceFrames.TryTrace(broken,now,out t),"torn payload checksum");
        broken=(uint[])trace.Clone();broken[30035]++;Check(!ForceTraceFrames.TryTrace(broken,now,out t),"sequence fence");
        broken=(uint[])trace.Clone();broken[7]=10002;Check(!ForceTraceFrames.TryTrace(broken,now,out t),"capacity validation");
        broken=(uint[])trace.Clone();broken[35]=0;ForceTraceFixture.TraceHash(broken);Check(!ForceTraceFrames.TryTrace(broken,now,out t),"nonmonotonic PLC time");
        broken=(uint[])trace.Clone();broken[33]=ForceTraceFixture.Bits(double.NaN);ForceTraceFixture.TraceHash(broken);Check(!ForceTraceFrames.TryTrace(broken,now,out t),"good NaN rejected");
        broken[34]=0;ForceTraceFixture.TraceHash(broken);Check(ForceTraceFrames.TryTrace(broken,now,out t),"invalid point retained as invalid");
        Check(!ForceTraceFrames.TryTrace(new uint[14],now,out t),"obsolete v1 binding rejected");
        var store=new ForceTraceStore();var frames=new ForceTraceFrames(store);
        // Late opening must accept an already complete buffer, whichever item arrives first.
        frames.ObserveTrace(trace,true,TracePosition.Left,now);frames.ObserveStatistics(stats,true,0);
        Check(store.Snapshot(TracePosition.Left)!=null,"late open with trace arriving first");
        TraceSnapshot completed=store.Snapshot(TracePosition.Left);
        var tornTrace=(uint[])trace.Clone();tornTrace[30035]++;
        frames.ObserveTrace(tornTrace,true,TracePosition.Left,now);
        Check(Object.ReferenceEquals(completed,store.Snapshot(TracePosition.Left)),"torn trace must not erase a verified completed curve");
        frames.ObserveTrace(trace,true,TracePosition.Left,now);
        Check(Object.ReferenceEquals(completed,store.Snapshot(TracePosition.Left)),"duplicate trace does not rebuild chart");
        var heartbeat=(uint[])trace.Clone();heartbeat[0]++;ForceTraceFixture.TraceHash(heartbeat);
        frames.ObserveTrace(heartbeat,true,TracePosition.Left,now);
        Check(Object.ReferenceEquals(completed,store.Snapshot(TracePosition.Left)),"terminal trace heartbeat does not rebuild chart");
        var tornStats=(uint[])stats.Clone();tornStats[208]^=1;
        frames.ObserveStatistics(tornStats,true,100);
        Check(frames.Connected && Object.ReferenceEquals(completed,store.Snapshot(TracePosition.Left)),"torn statistics cannot erase a current verified record");
        frames.ObserveStatistics(tornStats,true,500);
        Check(frames.Connected,"rejected packets do not end a still-current heartbeat");
        frames.CheckTimeout(501);Check(!frames.Connected && store.Snapshot(TracePosition.Left)==null,"stale communication never displays stability");
        frames.ObserveStatistics(stats,true,600);frames.ObserveTrace(trace,true,TracePosition.Left,now);
        Check(store.Snapshot(TracePosition.Left)!=null,"reconnect retains PLC history");
        var nextStats=ForceTraceFixture.Statistics(2);nextStats[0]=11;ForceTraceFixture.StatsHash(nextStats);
        frames.ObserveTrace(ForceTraceFixture.Trace(2),true,TracePosition.Left,now);frames.ObserveStatistics(nextStats,true,700);
        Check(store.Snapshot(TracePosition.Left).Cycle==2,"new-cycle trace before statistics survives");
        frames.ObserveStatistics(stats,true,710);Check(store.Snapshot(TracePosition.Left).Cycle==2,"old sequence does not rewind cycle");
        frames.ObserveTrace(trace,false,TracePosition.Left,now);Check(store.Snapshot(TracePosition.Left)==null,"bad selected-item quality clears curve");
        ForceTraceFrames.TryTrace(ForceTraceFixture.Trace(state:4),now,out t);
        ForceSample[] after=t.Select(TraceSaveRange.AfterStable);
        Check(after[0].Number==668 && after[0].ElapsedMs==4002 && after.Last().ElapsedMs==12000,"stable boundary inclusive; later fault included");
        Check(ForceTraceCsv.ToCsv(t,TraceSaveRange.AfterStable).Contains(",ProcessFault,"),"fault metadata exported");
        string tmp=Path.Combine(Path.GetTempPath(),"bpp-force-test-"+Guid.NewGuid().ToString("N"));
        try
        {
            ForceTraceFrames.TryTrace(ForceTraceFixture.Trace(stable:0),now,out t);
            try{ForceTraceCsv.Save(t,tmp,1000,512*1024*1024,TraceSaveRange.AfterStable);throw new Exception("expected refusal");}
            catch(InvalidOperationException e){Check(e.Message=="NoAfterStable" && !Directory.Exists(tmp),"no stable creates no file or folder");}
            var over=ForceTraceFixture.Trace(count:10001,stable:0);over[8]=1;over[17]=11000;over[9]=10500;over[10]=62994;over[11]=66000;ForceTraceFixture.TraceHash(over);
            Check(ForceTraceFrames.TryTrace(over,now,out t),"stable origin after retained capacity allowed");
            try{t.Select(TraceSaveRange.AfterStable);throw new Exception("expected refusal");}catch(InvalidOperationException){checks++;}
            ForceTraceFrames.TryTrace(ForceTraceFixture.Trace(state:1),now,out t);
            string file=ForceTraceCsv.Save(t,tmp,1000,512*1024*1024,TraceSaveRange.Full);
            Check(File.ReadAllText(file)==ForceTraceCsv.ToCsv(t,TraceSaveRange.Full) && file.Contains("-full-"),"running immutable snapshot full CSV");
            string file2=ForceTraceCsv.Save(t,tmp,1000,512*1024*1024,TraceSaveRange.AfterStable);
            Check(file2.Contains("-after_stable-") && Directory.GetFiles(tmp,"*.tmp").Length==0,"atomic second save range");
            try{ForceTraceCsv.Save(t,tmp,2,512*1024*1024,TraceSaveRange.Full);throw new Exception("expected quota");}catch(IOException){Check(Directory.GetFiles(tmp).Length==2,"quota does not delete history");}
        }
        finally{if(Directory.Exists(tmp))Directory.Delete(tmp,true);}
        CheckRefreshes(now);
        foreach(uint period in new uint[]{1,6,10})
        {
            Check(ForceTraceFrames.TryTrace(ForceTraceFixture.Trace(count:1001,stable:0,period:period),now,out t)
                && t.NominalSampleMs==period && t.Samples[1000].ElapsedMs==1000*period,"configured cycle preserves PLC timestamps");
            var variable=ForceTraceFixture.Statistics();variable[7]=period;variable[60]=period;ForceTraceFixture.StatsHash(variable);
            Check(ForceTraceFrames.TryStatistics(variable,out s) && s.Positions[0].NominalSampleMs==period,"statistics carries its own latched sampling period");
        }
        foreach(uint invalidPeriod in new uint[]{0,1001,UInt32.MaxValue})
        {
            var invalid=ForceTraceFixture.Trace();invalid[16]=invalidPeriod;ForceTraceFixture.TraceHash(invalid);
            Check(!ForceTraceFrames.TryTrace(invalid,now,out t),"invalid sampling period rejected");
        }
        var capacity=ForceTraceFixture.Trace(period:1);capacity[14]=10001;capacity[15]=20000;ForceTraceFixture.TraceHash(capacity);
        Check(!ForceTraceFrames.TryTrace(capacity,now,out t),"statistics window cannot exceed configured sample capacity");
        Console.WriteLine("PASS: "+checks+" PLC-frame, refresh, reconnect, PDF and CSV assertions");return 0;
    }
}
