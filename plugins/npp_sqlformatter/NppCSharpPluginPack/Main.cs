// Dit bestand vervangt NppCSharpPluginPack/NppCSharpPluginPack/Main.cs
// Kopieer het naar:  npp_sqlformatter/NppCSharpPluginPack/Main.cs
using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Text;
using System.Windows.Forms;
using Kbg.NppPluginNET.PluginInfrastructure;

namespace Kbg.NppPluginNET
{
    class Main
    {
        // ── Verplicht ──────────────────────────────────────────────────────────
        internal const string PluginName = "SQL Formatter";

        // Pad naar sql_formatter.exe naast de plugin-DLL
        static string ExePath =>
            Path.Combine(
                Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location),
                "sql_formatter.exe");

        // ── Verplichte hooks (aangeroepen vanuit UnmanagedExports.cs) ──────────
        public static void OnNotification(ScNotification notification) { }
        public static void PluginCleanUp() { }

        public static void SetToolBarIcons() { }

        internal static void CommandMenuInit()
        {
            PluginBase.SetCommand(0, "Format SQL",        FormatSQL,
                new ShortcutKey(true, true, false, Keys.F));
            PluginBase.SetCommand(1, "---",               null);
            PluginBase.SetCommand(2, "Over SQL Formatter", About);
        }

        // ── Hoofd-actie ────────────────────────────────────────────────────────
        static void FormatSQL()
        {
            if (!File.Exists(ExePath))
            {
                MessageBox.Show(
                    $"sql_formatter.exe niet gevonden op:\n{ExePath}\n\n" +
                    "Zet sql_formatter.exe in dezelfde map als SqlFormatter.dll.",
                    PluginName, MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }

            IntPtr sci = PluginBase.GetCurrentScintilla();
            var editor = new ScintillaGateway(sci);

            bool hasSelection = editor.GetSelectionStart() != editor.GetSelectionEnd();
            string sql = hasSelection ? editor.GetSelText()
                                      : editor.GetText((int)editor.GetLength() + 1);

            if (string.IsNullOrWhiteSpace(sql))
                return;

            try
            {
                string formatted = RunFormatter(sql);
                if (string.IsNullOrEmpty(formatted))
                    return;

                string output = formatted.TrimEnd() + "\n";
                if (hasSelection)
                    editor.ReplaceSel(output);
                else
                {
                    editor.SelectAll();
                    editor.ReplaceSel(output);
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Fout bij formatteren:\n{ex.Message}",
                    PluginName, MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        // ── sql_formatter.exe aanroepen via stdin/stdout ───────────────────────
        static string RunFormatter(string sql)
        {
            var psi = new ProcessStartInfo(ExePath)
            {
                UseShellExecute        = false,
                RedirectStandardInput  = true,
                RedirectStandardOutput = true,
                RedirectStandardError  = true,
                CreateNoWindow         = true,
                StandardOutputEncoding = new UTF8Encoding(false),
            };

            using (var proc = Process.Start(psi))
            {
                if (proc == null)
                    throw new Exception("Kon sql_formatter.exe niet starten.");

                proc.StandardInput.Write(sql);
                proc.StandardInput.Close();

                string output = proc.StandardOutput.ReadToEnd();
                string errors = proc.StandardError.ReadToEnd();
                proc.WaitForExit();

                if (proc.ExitCode != 0 && !string.IsNullOrWhiteSpace(errors))
                    throw new Exception(errors.Trim());

                return output;
            }
        }

        // ── Over-dialoog ───────────────────────────────────────────────────────
        static void About()
        {
            MessageBox.Show(
                "SQL Formatter plugin voor Notepad++\n\n" +
                "• Sneltoets:    Ctrl+Alt+F\n" +
                "• Selectie:     formatteert alleen de selectie\n" +
                "• Geen selectie: formatteert de hele tab\n\n" +
                "Gebaseerd op sql_formatter.exe (Python + PyInstaller).",
                PluginName, MessageBoxButtons.OK, MessageBoxIcon.Information);
        }
    }
}
