# VirtualSTM32 SSD1306 bridge for Renode/IronPython.
# Connects to Mocks.DummyI2CSlave named 'oled' at I2C1 address 0x3C and mirrors
# the 128x64 SSD1306 RAM into %TEMP%\VirtualSTM32\oled.bin.
# This intentionally implements the common command subset used by STM32 HAL SSD1306 libraries.

from System import Array, Byte
from System.IO import Path, Directory, File

W = 128
H = 64
PAGES = 8
fb = [0] * (W * PAGES)
display_on = True
inverse = False
col_start = 0
col_end = 127
page_start = 0
page_end = 7
col = 0
page = 0
address_mode = 0  # 0 horizontal, 1 vertical, 2 page
pending_cmd = None
pending = []

outdir = Path.Combine(Path.GetTempPath(), 'VirtualSTM32')
Directory.CreateDirectory(outdir)
outfile = Path.Combine(outdir, 'oled.bin')

def save_fb():
    try:
        File.WriteAllBytes(outfile, Array[Byte]([Byte(x & 0xFF) for x in fb]))
    except Exception as e:
        print 'VirtualSTM32 OLED write error: %s' % e

def reset_cursor():
    global col, page
    col = col_start
    page = page_start

def command_param_count(cmd):
    if cmd in (0x20, 0x81, 0x8D, 0xA8, 0xD3, 0xD5, 0xD9, 0xDA, 0xDB): return 1
    if cmd in (0x21, 0x22): return 2
    return 0

def execute_command(cmd, params):
    global display_on, inverse, col_start, col_end, page_start, page_end, col, page, address_mode
    if cmd == 0xAE: display_on = False
    elif cmd == 0xAF: display_on = True
    elif cmd == 0xA6: inverse = False
    elif cmd == 0xA7: inverse = True
    elif cmd == 0x20 and len(params) >= 1: address_mode = params[0] & 0x03
    elif cmd == 0x21 and len(params) >= 2:
        col_start, col_end = params[0] & 0x7F, params[1] & 0x7F
        col = col_start
    elif cmd == 0x22 and len(params) >= 2:
        page_start, page_end = params[0] & 0x07, params[1] & 0x07
        page = page_start
    elif 0xB0 <= cmd <= 0xB7:
        page = cmd & 0x07
    elif 0x00 <= cmd <= 0x0F:
        col = (col & 0xF0) | (cmd & 0x0F)
    elif 0x10 <= cmd <= 0x1F:
        col = (col & 0x0F) | ((cmd & 0x0F) << 4)

def feed_commands(items):
    global pending_cmd, pending
    for b in items:
        b = int(b) & 0xFF
        if pending_cmd is None:
            pending_cmd = b
            pending = []
            needed = command_param_count(pending_cmd)
            if needed == 0:
                execute_command(pending_cmd, pending)
                pending_cmd = None
        else:
            pending.append(b)
            if len(pending) >= command_param_count(pending_cmd):
                execute_command(pending_cmd, pending)
                pending_cmd = None
                pending = []

def advance_cursor():
    global col, page
    if address_mode == 1:  # vertical
        page += 1
        if page > page_end:
            page = page_start
            col += 1
            if col > col_end: col = col_start
    elif address_mode == 2:  # page
        col += 1
        if col > 127: col = 0
    else:  # horizontal
        col += 1
        if col > col_end:
            col = col_start
            page += 1
            if page > page_end: page = page_start

def feed_data(items):
    global col, page
    for b in items:
        if 0 <= col < W and 0 <= page < PAGES:
            fb[page * W + col] = int(b) & 0xFF
        advance_cursor()
    save_fb()

def on_i2c_data(data):
    arr = [int(x) & 0xFF for x in data]
    if len(arr) == 0: return
    control = arr[0]
    payload = arr[1:]
    if control == 0x00 or (control & 0x40) == 0:
        feed_commands(payload)
    else:
        feed_data(payload)

def find_oled():
    for name in ['sysbus.i2c1.oled', 'sysbus.oled', 'oled']:
        try:
            return monitor.Machine[name]
        except:
            pass
    raise Exception('VirtualSTM32: cannot find DummyI2CSlave oled peripheral')

oled = find_oled()
oled.DataReceived += on_i2c_data
save_fb()
print 'VirtualSTM32: SSD1306 bridge active, framebuffer=' + outfile
