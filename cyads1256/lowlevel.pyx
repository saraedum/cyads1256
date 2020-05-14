from libc.stdint cimport uint8_t, uint16_t, uint64_t, int32_t, uint32_t 

cdef extern from "bcm2835.h":
    uint8_t LOW
    uint8_t HIGH
    uint8_t BCM2835_GPIO_PUD_UP
    uint8_t BCM2835_GPIO_FSEL_INPT
    uint8_t BCM2835_GPIO_FSEL_OUTP
    uint8_t RPI_GPIO_P1_11
    uint8_t RPI_GPIO_P1_15
    uint16_t BCM2835_SPI_CLOCK_DIVIDER_1024
    uint8_t BCM2835_SPI_MODE1
    # LSBFIRST is unsupported says bcm.c?
    uint8_t BCM2835_SPI_BIT_ORDER_LSBFIRST
    void bcm2835_gpio_set_pud(uint8_t pin, uint8_t pud)
    void bcm2835_gpio_write(uint8_t pin, uint8_t on)
    void bcm2835_gpio_fsel(uint8_t pin, uint8_t mode)
    void bcm2835_spi_setClockDivider(uint16_t divider)
    void bcm2835_spi_setDataMode(uint8_t mode)
    void bcm2835_spi_setBitOrder(uint8_t order)
    uint8_t bcm2835_spi_transfer(uint8_t value)
    int bcm2835_spi_begin()
    int bcm2835_init()
    void bcm2835_delayMicroseconds (uint64_t micros)
    uint8_t bcm2835_gpio_lev(uint8_t pin)

# GPIO Pins
cdef uint8_t PIN_DRDY = RPI_GPIO_P1_11
cdef uint8_t PIN_SPICS = RPI_GPIO_P1_15

# ADS1256 Commands
cdef uint8_t CMD_WAKEUP  = 0x00
cdef uint8_t CMD_RDATA   = 0x01
cdef uint8_t CMD_RREG    = 0x10
cdef uint8_t CMD_WREG    = 0x50
cdef uint8_t CMD_SELFCAL = 0xF0
cdef uint8_t CMD_SYSOCAL = 0xF3
cdef uint8_t CMD_SYNC    = 0xFC

# ADS1256 Registers
cdef uint8_t REG_STATUS = 0
cdef uint8_t REG_MUX = 1

def ads_init(datarate, gain):
    if not bcm2835_init():
        raise RuntimeError("BCM2835 failed to initialize")
    if not bcm2835_spi_begin():
        raise RuntimeError("SPI failed to initialize. Are you root?")
    datarates = {
        30000 : int('11110000', 2),
        15000 : int('11100000', 2),
        7500  : int('11010000', 2),
        3750  : int('11000000', 2),
        2000  : int('10110000', 2),
        1000  : int('10100001', 2),
        500   : int('10010010', 2),
        100   : int('10000010', 2),
        60    : int('01110010', 2),
        50    : int('01100011', 2),
        30    : int('01010011', 2),
        25    : int('01000011', 2),
        15    : int('00110011', 2),
        10    : int('00100011', 2),
        5     : int('00010011', 2),
        2.5   : int('00000011', 2)}
    if datarate not in datarates:
        raise ValueError("unsupported datarate %s. must be one of %s"%(datarate, datarates.keys()))
    datarate = datarates[datarate]
    
    bcm2835_spi_setBitOrder(BCM2835_SPI_BIT_ORDER_LSBFIRST)
    bcm2835_spi_setDataMode(BCM2835_SPI_MODE1)
    bcm2835_spi_setClockDivider(BCM2835_SPI_CLOCK_DIVIDER_1024)
    bcm2835_gpio_fsel(PIN_SPICS, BCM2835_GPIO_FSEL_OUTP)
    bcm2835_gpio_write(PIN_SPICS, HIGH)
    bcm2835_gpio_fsel(PIN_DRDY, BCM2835_GPIO_FSEL_INPT)
    bcm2835_gpio_set_pud(PIN_DRDY, BCM2835_GPIO_PUD_UP)

    wait_DRDY()
    chip_id = read_reg(REG_STATUS) >> 4
    if chip_id != 3:
        raise RuntimeError("Unknown chip ID %s"%(chip_id, ))

    wait_DRDY()
    cdef uint8_t buf[4]
    from math import log
    buf[:] = [int('00000100', 2), 8, int(log(gain, 2)), datarate]
    bcm2835_gpio_write(PIN_SPICS, LOW)
    write(CMD_WREG)
    write(3)
    write(buf[0])
    write(buf[1])
    write(buf[2])
    write(buf[3])
    bcm2835_gpio_write(PIN_SPICS, HIGH)
    sleep(50)
    # calibration with inputs shortened
    # cmd(CMD_SYSOCAL)
    # wait_DRDY()
    # self calibration
    cmd(CMD_SELFCAL)
    wait_DRDY()

cdef void write(uint8_t byte):
    sleep(2)
    bcm2835_spi_transfer(byte)

cdef uint8_t read():
    return bcm2835_spi_transfer(0xff)

cdef void sleep(int usecs):
    bcm2835_delayMicroseconds(usecs)

cdef uint8_t read_reg(uint8_t register):
    bcm2835_gpio_write(PIN_SPICS, LOW)
    write(CMD_RREG | register)
    write(0)
    sleep(10)
    cdef uint8_t ret = read()
    bcm2835_gpio_write(PIN_SPICS, HIGH)
    return ret 

cdef void wait_DRDY():
    # TODO: use bcm to wait for the change
    while bcm2835_gpio_lev(PIN_DRDY): pass

cdef void set_channel(uint8_t channel):
    write_reg(REG_MUX, channel)

cpdef int32_t read_and_set_next_channel(uint8_t next_channel) except 2147483647:
    wait_DRDY()
    set_channel(next_channel)
    sleep(5)
    cmd(CMD_SYNC)
    sleep(5)
    cmd(CMD_WAKEUP)
    sleep(25)
    return read_data()

cdef int32_t read_data() except 2147483647:
    bcm2835_gpio_write(PIN_SPICS, LOW)
    cdef uint32_t buf[3]
    write(CMD_RDATA)
    sleep(10)
    buf[0] = read()
    buf[1] = read()
    buf[2] = read()
    bcm2835_gpio_write(PIN_SPICS, HIGH)

    cdef int32_t ret = (buf[0] << 16) | (buf[1] << 8) | buf[2]
    if (ret & 0x800000): ret |= <int32_t>0xFF000000;
    return ret

cdef void cmd(uint8_t command):
    bcm2835_gpio_write(PIN_SPICS, LOW)
    write(command)
    bcm2835_gpio_write(PIN_SPICS, HIGH)
    
cdef void write_reg(uint8_t register, uint8_t value):
    bcm2835_gpio_write(PIN_SPICS, LOW)
    write(CMD_WREG | register)
    write(0)
    write(value)
    bcm2835_gpio_write(PIN_SPICS, HIGH)
