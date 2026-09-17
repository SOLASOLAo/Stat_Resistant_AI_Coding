using System;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Threading;
using ForceTrace.Hmi;

internal static class ForceTraceStoreTests
{
    private static int checks;
    private static readonly DateTimeOffset At = new DateTimeOffset(2026, 9, 11, 1, 0, 0, TimeSpan.Zero);
    private static void Check(bool condition, string message)
    { checks++; if (!condition) throw new Exception(message); }
    private static void Throws<T>(Action action) where T : Exception
    {
        try { action(); } catch (T) { checks++; return; }
        throw new Exception("Expected " + typeof(T).Name);
    }

    public static int Main(string[] args)
    {
        string output = Path.GetFullPath(args[0]);
        Directory.CreateDirectory(output);
        ForceTraceStore store = new ForceTraceStore(20);
        Throws<InvalidOperationException>(() => store.Start(TracePosition.Left, At, 5));
        Throws<ArgumentException>(() => store.BeginCycle("=FORMULA()"));
        store.BeginCycle("test-cycle-1");
        store.Start(TracePosition.Left, At, 12.5);
        Throws<InvalidOperationException>(() => store.Start(TracePosition.Middle, At, 8));
        Check(!store.Observe(At, 0, 999, SampleQuality.Good, .1), "Initial timestamp was replayed.");
        store.Observe(At.AddMilliseconds(100), .1, 12.5, SampleQuality.Good, .1);
        store.Observe(At.AddMilliseconds(200), .2, 12.5, SampleQuality.Good, .1);
        TraceSnapshot running = store.Snapshot(TracePosition.Left, At.AddMilliseconds(200));
        Check(running.Samples.Count == 3 && running.EndReason == TraceEndReason.Running,
            "Constant force must still advance time.");
        Check(!store.Observe(At.AddMilliseconds(210), .1, 500, SampleQuality.Good, .1), "Out-of-order sample accepted.");
        store.End(TraceEndReason.Completed);
        store.End(TraceEndReason.ProcessFault);
        TraceSnapshot left = store.Snapshot(TracePosition.Left, At.AddSeconds(1));
        Check(left.EndReason == TraceEndReason.Completed, "First ending was overwritten.");
        Check(running.EndReason == TraceEndReason.Running, "An immutable snapshot changed.");
        Check(store.Snapshot(TracePosition.Middle, At) == null, "A result was invented for an unmeasured position.");
        Throws<InvalidOperationException>(() => store.Start(TracePosition.Left, At, 100));

        store.Start(TracePosition.Middle, At.AddSeconds(2), 20);
        store.Observe(At.AddSeconds(2.1), .1, 2000, SampleQuality.Good, .1);
        store.End(TraceEndReason.Cancelled);
        Check(store.Snapshot(TracePosition.Left, At).Samples[1].ForceN == 12.5, "Another position overwrote LEFT.");
        store.Start(TracePosition.Right, At.AddSeconds(3), 30);
        store.Observe(At.AddSeconds(3.5), .5, 3000, SampleQuality.Good, .1);
        TraceSnapshot right = store.Snapshot(TracePosition.Right, At);
        Check(right.Samples.Count == 3 && right.Samples[1].Quality == SampleQuality.Gap,
            "Missing observation interval was interpolated.");
        Check(!right.Samples[1].ForceN.HasValue && !right.Samples[1].ElapsedSeconds.HasValue, "Gap contains invented data.");
        store.Disconnect(At.AddSeconds(4));
        right = store.Snapshot(TracePosition.Right, At.AddSeconds(4));
        Check(right.EndReason == TraceEndReason.Disconnected && right.Samples.Last().Quality == SampleQuality.Disconnected,
            "Disconnection was not explicit.");
        Check(!store.Observe(At.AddSeconds(5), 2, 1, SampleQuality.Good, .1), "Reconnect appended to a closed trace.");

        CultureInfo previous = Thread.CurrentThread.CurrentCulture;
        string csv;
        try
        {
            Thread.CurrentThread.CurrentCulture = CultureInfo.GetCultureInfo("de-DE");
            csv = ForceTraceCsv.ToCsv(left);
            Check(csv.Contains(",0.1,12.5,Good,Completed"), "CSV depends on decimal-comma culture.");
            Check(csv.Split(new[] { "\r\n" }, StringSplitOptions.RemoveEmptyEntries).Length == left.Samples.Count + 1,
                "CSV sample count differs from the displayed snapshot.");
        }
        finally { Thread.CurrentThread.CurrentCulture = previous; }
        string first = ForceTraceCsv.Save(left, output, 10, 1000000);
        string second = ForceTraceCsv.Save(left, output, 10, 1000000);
        string interrupted = ForceTraceCsv.Save(right, output, 10, 1000000);
        Check(first != second && File.Exists(first) && File.Exists(second), "Repeated save overwrote a file.");
        Check(File.ReadAllText(first) == csv && File.ReadAllText(second) == csv, "Saved data differs from plotted snapshot.");
        Check(File.ReadAllText(interrupted).Contains(",,,Disconnected,Disconnected"), "Disconnected value was serialized as zero.");
        Throws<IOException>(() => ForceTraceCsv.Save(left, output, 1, 1000000));
        Throws<IOException>(() => ForceTraceCsv.Save(left, output, 10, 1024));
        string fileInsteadOfFolder = Path.Combine(output, "not-a-folder");
        File.WriteAllText(fileInsteadOfFolder, "Keep this file");
        Throws<IOException>(() => ForceTraceCsv.Save(left, fileInsteadOfFolder, 10, 1000000));
        Check(File.ReadAllText(fileInsteadOfFolder) == "Keep this file" && left.Samples.Count == 3,
            "Save failure damaged existing data.");
        Check(!Directory.EnumerateFiles(output, "*.tmp").Any(), "Save left a partial file.");

        store.BeginCycle("test-cycle-2");
        Check(store.Snapshot(TracePosition.Left, At) == null && store.Snapshot(TracePosition.Right, At) == null,
            "Previous cycle remained in the new cycle.");
        store.Start(TracePosition.Left, At, 1);
        store.Observe(At.AddSeconds(.1), .1, double.NaN, SampleQuality.Good, .1);
        TraceSnapshot invalid = store.Snapshot(TracePosition.Left, At);
        Check(invalid.EndReason == TraceEndReason.InvalidData && !invalid.Samples.Last().ForceN.HasValue,
            "Invalid number was silently accepted or replaced by zero.");
        ForceTraceStore bounded = new ForceTraceStore(2);
        bounded.BeginCycle("capacity");
        bounded.Start(TracePosition.Left, At, 1);
        bounded.Observe(At.AddSeconds(.1), .1, 2, SampleQuality.Good, .1);
        bounded.Observe(At.AddSeconds(.2), .2, 3, SampleQuality.Good, .1);
        TraceSnapshot full = bounded.Snapshot(TracePosition.Left, At);
        Check(full.Samples.Count == 2 && full.EndReason == TraceEndReason.Capacity, "Capacity did not stop bounded retention.");
        Console.WriteLine("PASS: " + checks + " force trace checks. Local CSV: " + first);
        return 0;
    }
}
