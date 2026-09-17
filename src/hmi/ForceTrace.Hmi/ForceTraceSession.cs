using System;
using System.Diagnostics;
using System.Windows.Forms;
using VisiWinNET.DataAccess;

namespace ForceTrace.Hmi
{
    // Two subscriptions: the selected retained trace plus all-position statistics.
    internal sealed class ForceTraceSession : IDisposable
    {
        internal readonly ForceTraceStore Store=new ForceTraceStore();
        internal readonly ForceTraceFrames Frames;
        private readonly Item[] traces;
        private readonly Item statistics;
        private readonly Stopwatch clock=Stopwatch.StartNew();
        private readonly Timer timer=new Timer();
        private TracePosition selected=TracePosition.Left;
        private bool statsAttached,traceAttached;
        private volatile bool refreshRetained;
        private long lastAttempt=-1000;
        internal ForceTraceSession(Item left,Item middle,Item right,Item stats)
        {
            traces=new[]{left,middle,right};statistics=stats;Frames=new ForceTraceFrames(Store);
            statistics.Change+=StatisticsChanged;
            foreach(Item i in traces)i.Change+=TraceChanged;
            timer.Interval=100;timer.Tick+=delegate {
                if(refreshRetained) {refreshRetained=false;Release(traces[(int)selected-1],ref traceAttached);lastAttempt=-1000;}
                TryAttach();Frames.CheckTimeout(clock.ElapsedMilliseconds);
            };
        }
        internal void Start() {TryAttach();timer.Start();}
        internal void Select(TracePosition position)
        {
            if(selected==position)return;
            Release(traces[(int)selected-1],ref traceAttached);
            selected=position;Store.ClearTrace(position);lastAttempt=-1000;TryAttach();
        }
        private void TryAttach()
        {
            if(clock.ElapsedMilliseconds-lastAttempt<1000)return;
            lastAttempt=clock.ElapsedMilliseconds;
            Attach(statistics,ref statsAttached);Attach(traces[(int)selected-1],ref traceAttached);
        }
        private static void Attach(Item item,ref bool attached)
        {
            if(attached || String.IsNullOrWhiteSpace(item.Name))return;
            try {attached=item.Attach();}
            catch(Exception) {try {item.Detach();}catch(Exception){} attached=false;}
        }
        private void StatisticsChanged(object sender,ChangeEventArgs args)
        {
            bool wasConnected=Frames.Connected;
            StatisticsSnapshot previous=Store.Statistics;
            Frames.ObserveStatistics(args.Value,args.Quality.Main==MainQualities.Good,clock.ElapsedMilliseconds);
            StatisticsSnapshot current=Store.Statistics;
            if(Frames.Connected && (!wasConnected || (previous!=null && current!=null && previous.BootId!=current.BootId)))refreshRetained=true;
        }
        private void TraceChanged(object sender,ChangeEventArgs args)
        {
            if(!Object.ReferenceEquals(sender,traces[(int)selected-1]))return;
            Frames.ObserveTrace(args.Value,args.Quality.Main==MainQualities.Good,selected,DateTimeOffset.UtcNow);
        }
        private static void Release(Item item,ref bool attached)
        {if(attached) {try {item.Detach();}finally {attached=false;}}}
        public void Dispose()
        {
            timer.Dispose();statistics.Change-=StatisticsChanged;
            foreach(Item i in traces)i.Change-=TraceChanged;
            Release(statistics,ref statsAttached);Release(traces[(int)selected-1],ref traceAttached);Frames.Disconnect();
        }
    }
}
