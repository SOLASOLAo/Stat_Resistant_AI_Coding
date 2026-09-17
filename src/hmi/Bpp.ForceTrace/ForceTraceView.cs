using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Drawing;
using System.Drawing.Design;
using System.Globalization;
using System.Threading.Tasks;
using System.Windows.Forms;
using Bosch.OpCon.HMI.Modulo.Forms;
using Bosch.OpCon.HMI.Modulo.Shared;
using VisiWinNET.DataAccess;
using VisiWinNET.LanguageSwitching;

namespace Bpp.ForceTrace
{
    public sealed class ForceTraceView : SmartControl
    {
        private const string ItemEditor="Bosch.OpCon.HMI.Modulo.Design.PlcItemEditor,OpCon.HMI.Modulo.Design,Version=5.11.0.0,Culture=neutral,PublicKeyToken=4241dc8872ae9833";
        private ForceTraceStore store=new ForceTraceStore();
        private ForceTraceSession session;
        private readonly Item left=new Item(),middle=new Item(),right=new Item(),statistics=new Item();
        private readonly Mod_Chart chart=new Mod_Chart();
        private readonly ChartYAxis forceAxis=new ChartYAxis();
        private readonly ChartChannel channel=new ChartChannel();
        private readonly DensityPlot density=new DensityPlot();
        private readonly Button[] positions=new Button[3];
        private readonly Button saveButton=new Button();
        private readonly ContextMenuStrip saveMenu=new ContextMenuStrip();
        private readonly ToolStripMenuItem fullMenu=new ToolStripMenuItem(),stableMenu=new ToolStripMenuItem();
        private readonly Label status=new Label(),metrics=new Label(),traceTitle=new Label(),distributionTitle=new Label();
        private readonly Timer refreshTimer=new Timer();
        private readonly Dictionary<string,LocalizedStateText> texts=new Dictionary<string,LocalizedStateText>();
        private TracePosition selected=TracePosition.Left;
        private TraceSnapshot displayed;
        private PositionStatistics shownStats;
        private bool saving,saveFailed,noAfterStable;
        private string savedPath,textGroup="Station";

        public ForceTraceView()
        {
            Size=new Size(944,572);BackColor=Color.White;Font=new Font("Microsoft YaHei UI",10);
            KeepAlive=true;SaveDirectory=@"C:\OpconData\ForceTraces";
            foreach(string key in new[]{"Left","Middle","Right","Save","Saving","Saved","SaveFailed","NoData","ForceAxis","TimeAxis",
                "FullRange","AfterStableRange","NoAfterStable","TraceTitle","DistributionTitle","DensityAxis","PdfReference","ZeroSpread",
                "Mean","ThreeSigma","Threshold","SigmaLimit","Window","Samples","Stable","Filling","Unstable","Frozen","Historical",
                "ConnectionLost","BindingRequired","Truncated"})AddText(key);
            foreach(string key in Enum.GetNames(typeof(TraceEndReason)))AddText(key);
            for(int i=0;i<3;i++)
            {
                TracePosition p=(TracePosition)(i+1);
                Button b=new Button{Location=new Point(12+i*176,12),Size=new Size(164,42),FlatStyle=FlatStyle.Flat};
                b.Click+=delegate{SelectPosition(p);};positions[i]=b;Controls.Add(b);
            }
            saveButton.SetBounds(668,12,264,42);saveButton.FlatStyle=FlatStyle.Flat;saveButton.Enabled=false;
            saveButton.Click+=delegate{saveMenu.Show(saveButton,new Point(0,saveButton.Height));};
            fullMenu.Click+=async delegate{await SaveRangeAsync(TraceSaveRange.Full);};
            stableMenu.Click+=async delegate{await SaveRangeAsync(TraceSaveRange.AfterStable);};
            saveMenu.Items.AddRange(new ToolStripItem[]{fullMenu,stableMenu});Controls.Add(saveButton);
            traceTitle.SetBounds(12,67,550,25);distributionTitle.SetBounds(582,67,350,25);
            Controls.Add(traceTitle);Controls.Add(distributionTitle);
            chart.SetBounds(12,97,552,320);chart.DataMode=ChartDataMode.Overwrite;chart.AllowFreeze=false;
            chart.Title.Visible=false;chart.ShowLabel=false;forceAxis.TitleVisible=true;forceAxis.GridVisible=true;
            chart.XAxis.TitleVisible=true;chart.XAxis.GridVisible=true;channel.ChannelColor=Color.FromArgb(0,90,140);
            forceAxis.Channels.Add(channel);chart.Axes.Add(forceAxis);chart.BeginInit();chart.EndInit();
            channel.Line.IgnoreNulls=false;channel.Line.Clear();chart.Visible=false;Controls.Add(chart);
            density.SetBounds(582,97,350,320);Controls.Add(density);
            metrics.SetBounds(12,433,920,74);Controls.Add(metrics);
            status.SetBounds(12,516,920,48);status.AutoEllipsis=true;Controls.Add(status);
            refreshTimer.Interval=100;refreshTimer.Tick+=delegate{RefreshSamples();};ApplyTexts();
        }
        [Editor(ItemEditor,typeof(UITypeEditor)),ItemType("ARRAY OF DWORD"),DesignerSerializationVisibility(DesignerSerializationVisibility.Content)]
        public Item LeftTraceItem {get{return left;}}
        [Editor(ItemEditor,typeof(UITypeEditor)),ItemType("ARRAY OF DWORD"),DesignerSerializationVisibility(DesignerSerializationVisibility.Content)]
        public Item MiddleTraceItem {get{return middle;}}
        [Editor(ItemEditor,typeof(UITypeEditor)),ItemType("ARRAY OF DWORD"),DesignerSerializationVisibility(DesignerSerializationVisibility.Content)]
        public Item RightTraceItem {get{return right;}}
        [Editor(ItemEditor,typeof(UITypeEditor)),ItemType("ARRAY OF DWORD"),DesignerSerializationVisibility(DesignerSerializationVisibility.Content)]
        public Item StatisticsItem {get{return statistics;}}
        [Browsable(false),DesignerSerializationVisibility(DesignerSerializationVisibility.Hidden)]
        public ForceTraceStore Store {get{return store;}}
        [Browsable(false),DesignerSerializationVisibility(DesignerSerializationVisibility.Hidden)]
        public TraceSnapshot DisplayedSnapshot {get{return displayed;}}
        [Browsable(false),DesignerSerializationVisibility(DesignerSerializationVisibility.Hidden)]
        public new Control.ControlCollection Controls {get{return base.Controls;}}
        [DefaultValue(@"C:\OpconData\ForceTraces")]
        public string SaveDirectory {get;set;}
        [DefaultValue("Station")]
        public string TextGroup {get{return textGroup;} set{textGroup=value;foreach(LocalizedStateText t in texts.Values)t.TextGroup=value;ApplyTexts();}}
        public LocalizedStateText GetLocalizedText(string key) {return texts[key];}
        public void SelectPosition(TracePosition position)
        {
            if(!Enum.IsDefined(typeof(TracePosition),position))throw new ArgumentOutOfRangeException("position");
            selected=position;displayed=null;savedPath=null;saveFailed=noAfterStable=false;
            if(session!=null)session.Select(position);RefreshSamples();
        }
        public void RefreshSamples()
        {
            TraceSnapshot next=store.Snapshot(selected);
            StatisticsSnapshot all=store.Statistics;
            PositionStatistics stat=all==null?null:all.Positions[(int)selected-1];
            if(stat!=null && stat.Acquisition==0)stat=null;
            if(!Object.ReferenceEquals(next,displayed))
            {
                if(next==null || displayed==null || next.CycleId!=displayed.CycleId || next.Acquisition!=displayed.Acquisition)
                {savedPath=null;saveFailed=noAfterStable=false;}
                displayed=next;channel.Line.Clear();
                if(next!=null)
                    foreach(ForceSample s in next.Samples)
                        if(s.Quality==SampleQuality.Good)channel.Line.Add(s.ElapsedSeconds,s.ForceN);
                        else channel.Line.Add(s.ElapsedSeconds,ForceTraceFrames.Finite(s.ForceN)?s.ForceN:0,Color.Transparent);
                chart.Visible=next!=null;chart.Invalidate();
            }
            if(next==null && channel.Line.Count!=0){channel.Line.Clear();chart.Visible=false;}
            shownStats=stat;density.Statistics=stat;density.Invalidate();
            saveButton.Enabled=!saving && next!=null;ApplyTexts();
        }
        public Task<string> SaveDisplayedAsync(TraceSaveRange range)
        {
            TraceSnapshot snapshot=displayed;string folder=SaveDirectory;
            return Task.Run(()=>ForceTraceCsv.Save(snapshot,folder,1000,512L*1024*1024,range));
        }
        private async Task SaveRangeAsync(TraceSaveRange range)
        {
            if(saving)return;
            saving=true;savedPath=null;saveFailed=noAfterStable=false;saveButton.Enabled=false;ApplyTexts();
            try {savedPath=await SaveDisplayedAsync(range);}
            catch(InvalidOperationException e) {noAfterStable=e.Message=="NoAfterStable";saveFailed=!noAfterStable;}
            catch(Exception) {saveFailed=true;}
            finally {saving=false;if(!IsDisposed)RefreshSamples();}
        }
        private void AddText(string key)
        {
            LocalizedStateText t=new LocalizedStateText{Text="ForceTrace"+key,TextGroup=textGroup};
            t.StateTextChange+=delegate{ApplyTexts();};texts.Add(key,t);
        }
        private string Caption(string key) {LocalizedStateText t;return texts.TryGetValue(key,out t)?t.DisplayText:"";}
        private static string Number(double value) {return value.ToString("0.###",CultureInfo.CurrentCulture);}
        private void ApplyTexts()
        {
            if(IsDisposed)return;
            if(InvokeRequired){BeginInvoke(new Action(ApplyTexts));return;}
            for(int i=0;i<3;i++)if(positions[i]!=null)
            {positions[i].Text=Caption(((TracePosition)(i+1)).ToString());positions[i].BackColor=i+1==(int)selected?Color.FromArgb(220,235,242):Color.White;}
            saveButton.Text=Caption(saving?"Saving":"Save");fullMenu.Text=Caption("FullRange");stableMenu.Text=Caption("AfterStableRange");
            traceTitle.Text=Caption("TraceTitle");distributionTitle.Text=Caption("DistributionTitle");
            forceAxis.Title=Caption("ForceAxis");chart.XAxis.Title=Caption("TimeAxis");
            density.AxisTitle=Caption("ForceAxis");density.DensityTitle=Caption("DensityAxis");density.ReferenceText=Caption("PdfReference");
            density.EmptyText=Caption("NoData");density.ConcentrationText=Caption("ZeroSpread");
            string phase=shownStats==null?"NoData":shownStats.State!=TraceEndReason.Running?shownStats.State.ToString():
                shownStats.Historical?"Historical":shownStats.Frozen?"Frozen":shownStats.Stable?"Stable":shownStats.Full?"Unstable":"Filling";
            if(shownStats==null)metrics.Text=Caption("NoData");
            else
            {
                bool hasWindow=shownStats.Count>0;
                metrics.Text=Caption("Mean")+": "+(hasWindow?Number(shownStats.Mean)+" N":"—")+"     "+Caption("ThreeSigma")+": "+(hasWindow?Number(shownStats.ThreeSigma)+" N":"—")
                    +"     "+Caption("Samples")+": "+shownStats.Count+"     "+Caption(phase)
                    +Environment.NewLine+Caption("Threshold")+": "+Number(shownStats.ThresholdN)+" N     "+Caption("SigmaLimit")+": "+Number(shownStats.SigmaLimitN)+" N"
                    +"     "+Caption("Window")+": "+shownStats.WindowMs+" ms";
                if(shownStats.Historical && phase!="Historical")metrics.Text+=Environment.NewLine+Caption("Historical");
            }
            bool disconnected=session!=null && !session.Frames.Connected;
            string key=saving?"Saving":noAfterStable?"NoAfterStable":saveFailed?"SaveFailed":savedPath!=null?"Saved":disconnected?"ConnectionLost":displayed==null?"NoData":displayed.EndReason.ToString();
            status.Text=Caption(key);
            if(displayed!=null && displayed.Truncated)status.Text+="  "+Caption("Truncated");
            if(savedPath!=null && !saving)status.Text+="  "+savedPath;
            status.ForeColor=noAfterStable || saveFailed || disconnected?Color.DarkOrange:Color.FromArgb(40,60,70);
        }
        protected override void OnLoad(EventArgs args)
        {
            base.OnLoad(args);
            if(DesignMode || LicenseManager.UsageMode==LicenseUsageMode.Designtime)return;
            for(Control p=Parent;p!=null;p=p.Parent)if(p.Site!=null && p.Site.DesignMode)return;
            if(String.IsNullOrWhiteSpace(left.Name)||String.IsNullOrWhiteSpace(middle.Name)||String.IsNullOrWhiteSpace(right.Name)||String.IsNullOrWhiteSpace(statistics.Name))
            {status.Text=Caption("BindingRequired");return;}
            session=new ForceTraceSession(left,middle,right,statistics);store=session.Store;session.Start();
            RefreshSamples();refreshTimer.Start();
        }
        protected override void Dispose(bool disposing)
        {
            if(disposing)
            {
                refreshTimer.Dispose();if(session!=null)session.Dispose();saveMenu.Dispose();
                left.Dispose();middle.Dispose();right.Dispose();statistics.Dispose();
                foreach(LocalizedStateText t in texts.Values)t.Dispose();
            }
            base.Dispose(disposing);
        }
    }

    // Twenty PLC histogram bins and a reference normal density from the same window.
    // This control never calculates stability or issues commands.
    internal sealed class DensityPlot : Control
    {
        internal PositionStatistics Statistics;
        internal string AxisTitle,DensityTitle,ReferenceText,EmptyText,ConcentrationText;
        internal DensityPlot() {DoubleBuffered=true;BackColor=Color.White;}
        protected override void OnPaint(PaintEventArgs args)
        {
            base.OnPaint(args);Graphics g=args.Graphics;g.SmoothingMode=System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
            RectangleF box=new RectangleF(50,32,Width-66,Height-102);
            using(Pen border=new Pen(Color.LightGray))g.DrawRectangle(border,box.X,box.Y,box.Width,box.Height);
            using(Brush ink=new SolidBrush(Color.FromArgb(50,60,70)))
            {
                g.DrawString(DensityTitle??"",Font,ink,4,7);
                g.DrawString(AxisTitle??"",Font,ink,box.X+box.Width/3,Height-43);
                g.DrawString(ReferenceText??"",Font,ink,4,Height-24);
                PositionStatistics s=Statistics;
                if(s==null || s.Count==0) {g.DrawString(EmptyText??"",Font,ink,box.X+12,box.Y+40);return;}
                if(s.Sigma==0 || s.BinWidth==0)
                {
                    using(Pen line=new Pen(Color.SteelBlue,3))g.DrawLine(line,box.X+box.Width/2,box.Bottom,box.X+box.Width/2,box.Y+30);
                    g.DrawString(ConcentrationText??"",Font,ink,box.X+4,box.Y+6);
                    g.DrawString(s.Mean.ToString("0.###"),Font,ink,box.X+box.Width/2-24,box.Bottom+3);return;
                }
                double lo=Math.Min(s.Minimum,s.Mean-3*s.Sigma),hi=Math.Max(s.Maximum,s.Mean+3*s.Sigma),peak=s.NormalDensity(s.Mean);
                for(int i=0;i<20;i++)peak=Math.Max(peak,s.Density(i));peak*=1.1;
                if(!ForceTraceFrames.Finite(peak)||peak<=0||hi<=lo)return;
                using(Brush bars=new SolidBrush(Color.FromArgb(160,0,110,150)))
                    for(int i=0;i<20;i++)
                    {
                        float x=box.X+(float)((s.BinMinimum+i*s.BinWidth-lo)/(hi-lo))*box.Width;
                        float w=(float)(s.BinWidth/(hi-lo))*box.Width;
                        float h=(float)(s.Density(i)/peak)*box.Height;
                        g.FillRectangle(bars,x,box.Bottom-h,Math.Max(1,w-1),h);
                    }
                PointF[] curve=new PointF[101];
                for(int i=0;i<curve.Length;i++)
                {double x=lo+(hi-lo)*i/100;curve[i]=new PointF(box.X+box.Width*i/100,box.Bottom-(float)(s.NormalDensity(x)/peak)*box.Height);}
                using(Pen pdf=new Pen(Color.DarkOrange,2))g.DrawLines(pdf,curve);
                g.DrawString(lo.ToString("0.#"),Font,ink,box.X-8,box.Bottom+3);
                g.DrawString(hi.ToString("0.#"),Font,ink,box.Right-42,box.Bottom+3);
                g.DrawString(peak.ToString("0.###"),Font,ink,0,box.Y);
                g.DrawString("0",Font,ink,box.X-16,box.Bottom-14);
            }
        }
    }
}
