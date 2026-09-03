using System;
using System.IO;
using Antmicro.Renode.Peripherals;

namespace Antmicro.Renode.Peripherals.Miscellaneous
{
    // Host-side display sink for one Renode GPIO output.
    // It intentionally has no timing logic and cannot block the emulated MCU.
    public sealed class VirtualSTM32LedBridge : IPeripheral, IGPIOReceiver
    {
        public VirtualSTM32LedBridge(string id)
        {
            if(string.IsNullOrWhiteSpace(id))
            {
                throw new ArgumentException("LED bridge id cannot be empty.", nameof(id));
            }

            outputDirectory = Path.Combine(Path.GetTempPath(), "VirtualSTM32");
            outputPath = Path.Combine(outputDirectory, id + ".state");

            Directory.CreateDirectory(outputDirectory);
            SetState(false, force: true);
        }

        public bool State { get; private set; }

        public void OnGPIO(int number, bool value)
        {
            SetState(value, force: false);
        }

        public void Reset()
        {
            SetState(false, force: true);
        }

        private void SetState(bool value, bool force)
        {
            if(!force && initialized && State == value)
            {
                return;
            }

            State = value;
            initialized = true;

            try
            {
                Directory.CreateDirectory(outputDirectory);
                File.WriteAllText(outputPath, value ? "1" : "0");
            }
            catch(Exception)
            {
                // Display bridging must never stop emulation.
            }
        }

        private readonly string outputDirectory;
        private readonly string outputPath;
        private bool initialized;
    }
}
