using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

internal static class ObsidianNoteSaverLauncher
{
    [STAThread]
    private static int Main()
    {
        try
        {
            string baseDirectory = AppDomain.CurrentDomain.BaseDirectory;
            string scriptPath = Path.Combine(baseDirectory, "ObsidianNoteSaver.ps1");
            string powerShellPath = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.Windows),
                @"System32\WindowsPowerShell\v1.0\powershell.exe");

            if (!File.Exists(scriptPath))
            {
                MessageBox.Show(
                    "ObsidianNoteSaver.ps1 파일을 찾을 수 없습니다.",
                    "Obsidian Note Saver",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);
                return 1;
            }

            var startInfo = new ProcessStartInfo
            {
                FileName = powerShellPath,
                Arguments = "-NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File " + Quote(scriptPath),
                WorkingDirectory = baseDirectory,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            Process.Start(startInfo);
            return 0;
        }
        catch (Exception exception)
        {
            MessageBox.Show(
                exception.Message,
                "Obsidian Note Saver",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
            return 1;
        }
    }

    private static string Quote(string value)
    {
        return "\"" + value.Replace("\"", "\\\"") + "\"";
    }
}
