using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;

namespace Bpp.ForceTrace
{
    // Position identifiers retain fixture coordinates: Left fixture = right workpiece.
    public enum TracePosition { Left = 1, Middle = 2, Right = 3 }
    public enum SampleQuality { Invalid = 0, Good = 1, Gap = 2 }
    public enum TraceEndReason { Empty = 0, Running = 1, Completed = 2, Cancelled = 3, ProcessFault = 4, InvalidData = 5 }
    public enum TraceSaveRange { Full, AfterStable }

    public sealed class ForceSample
    {
        public readonly uint Number, ElapsedMs;
        public readonly double ForceN;
        public readonly SampleQuality Quality;
        public double ElapsedSeconds { get { return ElapsedMs / 1000.0; } }
        internal ForceSample(uint number, uint elapsed, double force, SampleQuality quality)
        { Number = number; ElapsedMs = elapsed; ForceN = force; Quality = quality; }
    }

    public sealed class TraceSnapshot
    {
        public readonly uint BootId, Cycle, Acquisition, Sequence, FirstStableSample, FirstStableMs;
        public readonly uint WindowMs, TimeoutMs, NominalSampleMs, StreamCount, ElapsedMs;
        public readonly double ThresholdN, SigmaLimitN;
        public readonly bool Truncated;
        public readonly TracePosition Position;
        public readonly DateTimeOffset CapturedAtUtc;
        public readonly TraceEndReason EndReason;
        public readonly ReadOnlyCollection<ForceSample> Samples;
        public string CycleId { get { return "b" + BootId + "_c" + Cycle; } }
        internal TraceSnapshot(uint[] w, ForceSample[] samples, DateTimeOffset received)
        {
            Sequence=w[0]; BootId=w[2]; Cycle=w[3]; Acquisition=w[4]; Position=(TracePosition)w[5];
            EndReason=(TraceEndReason)w[6]; Truncated=w[8]!=0; FirstStableSample=w[9]; FirstStableMs=w[10];
            ElapsedMs=w[11]; ThresholdN=ForceTraceFrames.Float(w[12]); SigmaLimitN=ForceTraceFrames.Float(w[13]);
            WindowMs=w[14]; TimeoutMs=w[15]; NominalSampleMs=w[16]; StreamCount=w[17];
            CapturedAtUtc=received.ToUniversalTime(); Samples=Array.AsReadOnly(samples);
        }
        public ForceSample[] Select(TraceSaveRange range)
        {
            if (!Enum.IsDefined(typeof(TraceSaveRange),range)) throw new ArgumentOutOfRangeException("range");
            if (range==TraceSaveRange.AfterStable && (FirstStableSample==0 || FirstStableSample>Samples.Count))
                throw new InvalidOperationException("NoAfterStable");
            ForceSample[] points=Samples.Where(s=>range==TraceSaveRange.Full || s.Number>=FirstStableSample).ToArray();
            if (!points.Any(s=>s.Quality==SampleQuality.Good))
                throw new InvalidOperationException(range==TraceSaveRange.AfterStable?"NoAfterStable":"NoData");
            return points;
        }
    }

    public sealed class PositionStatistics
    {
        public readonly uint Acquisition, Count, WindowMs, TimeoutMs, FirstStableSample, FirstStableMs, ElapsedMs, FirstMs, LastMs;
        public readonly TracePosition Position;
        public readonly TraceEndReason State;
        public readonly bool Healthy, Full, Stable, Frozen, Historical;
        public readonly double ForceN, Mean, Sigma, ThreeSigma, Minimum, Maximum, ThresholdN, SigmaLimitN, BinMinimum, BinWidth;
        public readonly ReadOnlyCollection<uint> Bins;
        internal PositionStatistics(uint[] w,int b,int position)
        {
            Position=(TracePosition)position; Acquisition=w[b+1]; State=(TraceEndReason)w[b+2]; Count=w[b+3];
            Healthy=(w[b+4]&1)!=0; Full=(w[b+4]&2)!=0; Stable=(w[b+4]&4)!=0;
            Frozen=(w[b+4]&8)!=0; Historical=(w[b+4]&16)!=0;
            ForceN=ForceTraceFrames.Float(w[b+5]); Mean=ForceTraceFrames.Float(w[b+6]);
            Sigma=ForceTraceFrames.Float(w[b+7]); ThreeSigma=ForceTraceFrames.Float(w[b+8]);
            Minimum=ForceTraceFrames.Float(w[b+9]); Maximum=ForceTraceFrames.Float(w[b+10]);
            ThresholdN=ForceTraceFrames.Float(w[b+11]); SigmaLimitN=ForceTraceFrames.Float(w[b+12]);
            WindowMs=w[b+13]; TimeoutMs=w[b+14]; ElapsedMs=w[b+15]; FirstMs=w[b+16]; LastMs=w[b+17];
            FirstStableSample=w[b+18]; FirstStableMs=w[b+19];
            BinMinimum=ForceTraceFrames.Float(w[b+20]); BinWidth=ForceTraceFrames.Float(w[b+21]);
            uint[] bins=new uint[20]; Array.Copy(w,b+23,bins,0,20); Bins=Array.AsReadOnly(bins);
        }
        public double Density(int bin) { return Count>0 && BinWidth>0 ? Bins[bin]/(Count*BinWidth) : 0; }
        public double NormalDensity(double force)
        {
            if (Count<2 || Sigma<=0) return 0;
            double z=(force-Mean)/Sigma;
            return Math.Exp(-0.5*z*z)/(Sigma*Math.Sqrt(2*Math.PI));
        }
    }
    public sealed class StatisticsSnapshot
    {
        public readonly uint BootId,Cycle,Sequence,PlcTime;
        public readonly ReadOnlyCollection<PositionStatistics> Positions;
        internal StatisticsSnapshot(uint[] w,PositionStatistics[] positions)
        { Sequence=w[0];BootId=w[2];Cycle=w[3];PlcTime=w[5];Positions=Array.AsReadOnly(positions); }
    }

    // Cache of immutable PLC snapshots, never an HMI sampler or process judge.
    public sealed class ForceTraceStore
    {
        private readonly object gate=new object();
        private readonly Dictionary<TracePosition,TraceSnapshot> traces=new Dictionary<TracePosition,TraceSnapshot>();
        private StatisticsSnapshot statistics;
        public StatisticsSnapshot Statistics { get { lock(gate) return statistics; } }
        public void Accept(StatisticsSnapshot next)
        {
            lock(gate)
            {
                foreach(TracePosition p in traces.Keys.ToArray())
                    if(traces[p].BootId!=next.BootId || traces[p].Cycle!=next.Cycle || traces[p].Acquisition!=next.Positions[(int)p-1].Acquisition)
                        traces.Remove(p);
                statistics=next;
            }
        }
        public void Accept(TraceSnapshot next) { lock(gate) traces[next.Position]=next; }
        public void Clear() { lock(gate) { statistics=null; traces.Clear(); } }
        public void ClearTrace(TracePosition position) { lock(gate) traces.Remove(position); }
        public TraceSnapshot Snapshot(TracePosition position)
        {
            lock(gate)
            {
                TraceSnapshot t;
                if(statistics==null || !traces.TryGetValue(position,out t) || t.BootId!=statistics.BootId || t.Cycle!=statistics.Cycle) return null;
                PositionStatistics s=statistics.Positions[(int)position-1];
                return s.Acquisition==t.Acquisition && t.Samples.Count>0 ? t : null;
            }
        }
    }

    public static class ForceTraceCsv
    {
        private static readonly object saveGate=new object();
        public static string Save(TraceSnapshot snapshot,string directory,int maxFiles,long maxDirectoryBytes,TraceSaveRange range)
        {
            if(snapshot==null) throw new InvalidOperationException(range==TraceSaveRange.AfterStable?"NoAfterStable":"NoData");
            if(maxFiles<1 || maxDirectoryBytes<1024) throw new ArgumentOutOfRangeException("maxFiles");
            // Validate selection before creating even a directory or temporary file.
            byte[] data=new UTF8Encoding(false).GetBytes(ToCsv(snapshot,range));
            string folder=Path.GetFullPath(directory);
            lock(saveGate)
            {
                Directory.CreateDirectory(folder);
                long bytes=0; int files=0;
                foreach(string path in Directory.EnumerateFiles(folder,"force-*.csv"))
                {
                    bytes+=new FileInfo(path).Length; files++;
                    if(files>=maxFiles || bytes>maxDirectoryBytes-data.Length) throw new IOException("Force trace storage limit reached.");
                }
                if(files>=maxFiles || bytes>maxDirectoryBytes-data.Length) throw new IOException("Force trace storage limit reached.");
                string stem="force-"+snapshot.CapturedAtUtc.ToString("yyyyMMdd'T'HHmmssfff'Z'",CultureInfo.InvariantCulture)
                    +"-"+snapshot.CycleId+"-"+snapshot.Position.ToString().ToLowerInvariant()+"-"+RangeName(range)+"-"+Guid.NewGuid().ToString("N");
                string final=Path.Combine(folder,stem+".csv"),temporary=Path.Combine(folder,stem+".tmp");
                try
                {
                    using(FileStream stream=new FileStream(temporary,FileMode.CreateNew,FileAccess.Write,FileShare.None))
                    {stream.Write(data,0,data.Length);stream.Flush(true);}
                    File.Move(temporary,final);return final;
                }
                catch {if(File.Exists(temporary))File.Delete(temporary);throw;}
            }
        }
        public static string RangeName(TraceSaveRange range) { return range==TraceSaveRange.Full?"full":"after_stable"; }
        public static string ToCsv(TraceSnapshot snapshot,TraceSaveRange range)
        {
            if(snapshot==null)throw new ArgumentNullException("snapshot");
            ForceSample[] points=snapshot.Select(range);
            StringBuilder text=new StringBuilder("schema_version,cycle_id,acquisition,fixture_position,range,snapshot_received_at_utc,sample_number,elapsed_ms,force_n,data_quality,end_reason,truncated,force_threshold_n,three_sigma_limit_n,window_ms,timeout_ms,nominal_sample_ms,first_stable_sample,first_stable_ms,snapshot_end_ms\r\n");
            foreach(ForceSample s in points)
            {
                text.Append("2,").Append(snapshot.CycleId).Append(',').Append(snapshot.Acquisition).Append(',')
                    .Append(snapshot.Position.ToString().ToUpperInvariant()).Append(',').Append(RangeName(range)).Append(',')
                    .Append(snapshot.CapturedAtUtc.ToString("o",CultureInfo.InvariantCulture)).Append(',')
                    .Append(s.Number).Append(',').Append(s.ElapsedMs).Append(',')
                    .Append(ForceTraceFrames.Finite(s.ForceN)?Number(s.ForceN):"").Append(',').Append(s.Quality).Append(',')
                    .Append(snapshot.EndReason).Append(',').Append(snapshot.Truncated?1:0).Append(',')
                    .Append(Number(snapshot.ThresholdN)).Append(',').Append(Number(snapshot.SigmaLimitN)).Append(',')
                    .Append(snapshot.WindowMs).Append(',').Append(snapshot.TimeoutMs).Append(',').Append(snapshot.NominalSampleMs).Append(',')
                    .Append(snapshot.FirstStableSample).Append(',').Append(snapshot.FirstStableMs).Append(',').Append(snapshot.ElapsedMs).Append("\r\n");
            }
            return text.ToString();
        }
        private static string Number(double value) {return value.ToString("R",CultureInfo.InvariantCulture);}
    }
}
