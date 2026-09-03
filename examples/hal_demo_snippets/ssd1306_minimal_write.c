#include "i2c.h"
#include <string.h>

#define OLED_ADDR (0x3C << 1)

static void oled_cmd(uint8_t c)
{
    uint8_t p[2] = {0x00, c};
    HAL_I2C_Master_Transmit(&hi2c1, OLED_ADDR, p, sizeof(p), HAL_MAX_DELAY);
}

static void oled_cmd1(uint8_t c, uint8_t a)
{
    uint8_t p[3] = {0x00, c, a};
    HAL_I2C_Master_Transmit(&hi2c1, OLED_ADDR, p, sizeof(p), HAL_MAX_DELAY);
}

static void oled_cmd2(uint8_t c, uint8_t a, uint8_t b)
{
    uint8_t p[4] = {0x00, c, a, b};
    HAL_I2C_Master_Transmit(&hi2c1, OLED_ADDR, p, sizeof(p), HAL_MAX_DELAY);
}

static void oled_data(const uint8_t* data, uint16_t len)
{
    // Control byte + payload. Small blocks keep stack usage low and work with HAL I2C.
    uint8_t block[33];
    block[0] = 0x40;
    while(len) {
        uint16_t n = len > 32 ? 32 : len;
        memcpy(&block[1], data, n);
        HAL_I2C_Master_Transmit(&hi2c1, OLED_ADDR, block, n + 1, HAL_MAX_DELAY);
        data += n;
        len -= n;
    }
}

void oled_demo(void)
{
    static uint8_t fb[1024];

    oled_cmd(0xAE);             // display off
    oled_cmd1(0x20, 0x00);      // horizontal addressing mode
    oled_cmd2(0x21, 0, 127);    // column range
    oled_cmd2(0x22, 0, 7);      // page range
    oled_cmd(0xA6);             // normal display
    oled_cmd(0xAF);             // display on

    memset(fb, 0, sizeof(fb));
    // A visible stripe/check pattern in the first page.
    for(int x = 0; x < 128; ++x) {
        fb[x] = (x & 1) ? 0xAA : 0x55;
    }
    oled_data(fb, sizeof(fb));
}
