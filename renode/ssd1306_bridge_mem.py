# VirtualSTM32 SSD1306 bridge - Patch 033B1
# Renode IronPython.
#
# Robustness changes vs 033B:
# - use SystemBus absolute accesses, not direct MappedMemory object methods
# - do not clear 1024 bytes during include
# - never abort the whole runtime script if OLED bridge init fails
# - publish a small status word in mapped memory for diagnostics

from System import Byte, UInt32, UInt64

W = 128
PAGES = 8
FB_SIZE = W * PAGES

# This is NOT a separately registered peripheral.
# Stock STM32F103 already provides fsmcBank1 at 0x60000000.
# VirtualSTM32 reserves its first 0x1000 bytes as an internal OLED mailbox.
FB_BASE = 0x60000000
META_GENERATION = FB_BASE + 0x404
META_FLAGS = FB_BASE + 0x408
META_MAGIC = FB_BASE + 0x40C
META_STATUS = FB_BASE + 0x410

FLAG_DISPLAY_ON = 0x01
FLAG_INVERSE = 0x02
FLAG_ALL_ON = 0x04

STATUS_INIT = 0xB033B101
STATUS_READY = 0xB033B1FF
STATUS_NO_SYSBUS = 0xE033B101
STATUS_NO_OLED = 0xE033B102
STATUS_EVENT_ERROR = 0xE033B103

fb = [0] * FB_SIZE

display_on = False
inverse = False
all_on = False

col_start = 0
col_end = 127
page_start = 0
page_end = 7

col = 0
page = 0
address_mode = 0

pending_cmd = None
pending = []
generation = 0

sysbus = None
oled = None


def write_u32(address, value):
    sysbus.WriteDoubleWord(
        UInt64(int(address)),
        UInt32(int(value) & 0xFFFFFFFF)
    )


def write_byte(address, value):
    sysbus.WriteByte(
        UInt64(int(address)),
        Byte(int(value) & 0xFF)
    )


def current_flags():
    flags = 0

    if display_on:
        flags |= FLAG_DISPLAY_ON

    if inverse:
        flags |= FLAG_INVERSE

    if all_on:
        flags |= FLAG_ALL_ON

    return flags


def commit():
    global generation

    generation = (generation + 1) & 0xFFFFFFFF

    write_u32(META_FLAGS, current_flags())
    write_u32(META_GENERATION, generation)

    # ASCII "OLED", little endian.
    write_byte(META_MAGIC + 0, ord('O'))
    write_byte(META_MAGIC + 1, ord('L'))
    write_byte(META_MAGIC + 2, ord('E'))
    write_byte(META_MAGIC + 3, ord('D'))


def command_param_count(cmd):
    if cmd in (
        0x20,
        0x81,
        0x8D,
        0xA8,
        0xD3,
        0xD5,
        0xD9,
        0xDA,
        0xDB
    ):
        return 1

    if cmd in (0x21, 0x22):
        return 2

    return 0


def execute_command(cmd, params):
    global display_on, inverse, all_on
    global col_start, col_end, page_start, page_end
    global col, page, address_mode

    cmd = int(cmd) & 0xFF

    if cmd == 0xAE:
        display_on = False

    elif cmd == 0xAF:
        display_on = True

    elif cmd == 0xA6:
        inverse = False

    elif cmd == 0xA7:
        inverse = True

    elif cmd == 0xA4:
        all_on = False

    elif cmd == 0xA5:
        all_on = True

    elif cmd == 0x20 and len(params) >= 1:
        address_mode = int(params[0]) & 0x03

    elif cmd == 0x21 and len(params) >= 2:
        col_start = int(params[0]) & 0x7F
        col_end = int(params[1]) & 0x7F

        if col_end < col_start:
            col_end = col_start

        col = col_start

    elif cmd == 0x22 and len(params) >= 2:
        page_start = int(params[0]) & 0x07
        page_end = int(params[1]) & 0x07

        if page_end < page_start:
            page_end = page_start

        page = page_start

    elif 0xB0 <= cmd <= 0xB7:
        page = cmd & 0x07

    elif 0x00 <= cmd <= 0x0F:
        col = (col & 0xF0) | (cmd & 0x0F)

    elif 0x10 <= cmd <= 0x1F:
        col = (col & 0x0F) | ((cmd & 0x0F) << 4)


def feed_commands(items):
    global pending_cmd, pending

    visual_changed = False

    for raw in items:
        b = int(raw) & 0xFF

        if pending_cmd is None:
            pending_cmd = b
            pending = []

            if command_param_count(pending_cmd) == 0:
                before = current_flags()

                execute_command(
                    pending_cmd,
                    pending
                )

                after = current_flags()

                if before != after:
                    visual_changed = True

                pending_cmd = None

        else:
            pending.append(b)

            if len(pending) >= command_param_count(pending_cmd):
                before = current_flags()

                execute_command(
                    pending_cmd,
                    pending
                )

                after = current_flags()

                if before != after:
                    visual_changed = True

                pending_cmd = None
                pending = []

    if visual_changed:
        commit()


def advance_cursor():
    global col, page

    if address_mode == 1:
        # vertical addressing
        page += 1

        if page > page_end:
            page = page_start
            col += 1

            if col > col_end:
                col = col_start

    elif address_mode == 2:
        # page addressing
        col += 1

        if col > 127:
            col = 0

    else:
        # horizontal addressing
        col += 1

        if col > col_end:
            col = col_start
            page += 1

            if page > page_end:
                page = page_start


def feed_data(items):
    global col, page

    wrote = False

    for raw in items:
        b = int(raw) & 0xFF

        if 0 <= col < W and 0 <= page < PAGES:
            index = page * W + col

            fb[index] = b

            write_byte(
                FB_BASE + index,
                b
            )

            wrote = True

        advance_cursor()

    if wrote:
        commit()


def on_i2c_data(data):
    try:
        arr = [int(x) & 0xFF for x in data]

        if len(arr) == 0:
            return

        control = arr[0]
        payload = arr[1:]

        # SSD1306 control-byte D/C# bit.
        if (control & 0x40) != 0:
            feed_data(payload)
        else:
            feed_commands(payload)

    except Exception as e:
        try:
            write_u32(META_STATUS, STATUS_EVENT_ERROR)
        except:
            pass

        print "VSTM32_SSD1306_EVENT_ERROR: " + str(e)


# -------------------------------------------------------------
# Initialization must never abort runtime.resc.
# -------------------------------------------------------------
try:
    sysbus = monitor.Machine["sysbus"]

    try:
        write_u32(META_STATUS, STATUS_INIT)
    except:
        pass

    candidates = [
        "sysbus.i2c1.ssd1306",
        "sysbus.ssd1306",
        "ssd1306"
    ]

    for path in candidates:
        try:
            oled = monitor.Machine[path]
            break
        except:
            pass

    if oled is None:
        write_u32(META_STATUS, STATUS_NO_OLED)
        print "VSTM32_SSD1306_BRIDGE_ERROR: SSD1306 peripheral not found"

    else:
        # MappedMemory starts as zero; no expensive 1024-byte clear here.
        write_u32(META_GENERATION, 0)
        write_u32(META_FLAGS, 0)

        write_byte(META_MAGIC + 0, ord('O'))
        write_byte(META_MAGIC + 1, ord('L'))
        write_byte(META_MAGIC + 2, ord('E'))
        write_byte(META_MAGIC + 3, ord('D'))

        oled.DataReceived += on_i2c_data

        write_u32(META_STATUS, STATUS_READY)

        print "VSTM32_SSD1306_BRIDGE_READY framebuffer=0x60000000 size=1024"

except Exception as e:
    print "VSTM32_SSD1306_BRIDGE_ERROR: " + str(e)

