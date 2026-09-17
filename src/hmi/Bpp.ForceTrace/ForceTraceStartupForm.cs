using System;
using System.ComponentModel;
using VisiWinNET.Forms;

namespace Bpp.ForceTrace
{
    // Native ProjectForms preloading requires a SmartForm, not the chart page's
    // SmartControl. EndInit runs during preload even though this form is hidden.
    public sealed class ForceTraceStartupForm : SmartForm, ISupportInitialize
    {
        private ForceTraceSession session;

        public ForceTraceStartupForm()
        {
            LoadDefaultContent = false;
            ShowInTaskbar = false;
            FrameItemName = "";
        }

        [DefaultValue("")]
        public string FrameItemName { get; set; }

        public new void EndInit()
        {
            base.EndInit();
            if (DesignMode || LicenseManager.UsageMode == LicenseUsageMode.Designtime ||
                String.IsNullOrWhiteSpace(FrameItemName)) return;
            session = ForceTraceSession.Get(FrameItemName);
            session.Start();
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing && session != null) { session.Dispose(); session = null; }
            base.Dispose(disposing);
        }
    }
}
