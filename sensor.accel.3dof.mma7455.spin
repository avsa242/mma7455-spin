{
---------------------------------------------------------------------------------------------------
    Filename:       sensor.accel.3dof.mma7455.spin
    Description:    Driver for the NXP/Freescale MMA7455 3-axis accelerometer
    Author:         Jesse Burt
    Started:        Nov 27, 2019
    Updated:        Nov 19, 2025
    Copyright (c) 2025 - See end of file for terms of use.
---------------------------------------------------------------------------------------------------
}

#include "sensor.accel.common.spinh"

CON

    { default I/O configuration - these can be overridden by the parent object }
    SCL         = 28
    SDA         = 29
    I2C_FREQ    = 400_000
    I2C_ADDR    = 0


    ' Indicate to user apps how many Degrees of Freedom each sub-sensor has
    '   (also imply whether or not it has a particular sensor)
    ACCEL_DOF   = 3
    GYRO_DOF    = 0
    MAG_DOF     = 0
    BARO_DOF    = 0
    DOF         = ACCEL_DOF + GYRO_DOF + MAG_DOF + BARO_DOF

    R           = 0
    W           = 1

    ' Scales and data rates used during calibration/bias/offset process
    CAL_XL_SCL  = 2
    CAL_G_SCL   = 0
    CAL_M_SCL   = 0
    CAL_XL_DR   = 250
    CAL_G_DR    = 0
    CAL_M_DR    = 0


    ' Operating modes
    #0, STANDBY, MEASURE, LEVELDET, PULSEDET

    ' Individual axes
    X_AXIS      = 0
    Y_AXIS      = 1
    Z_AXIS      = 2

    ' Clear interrupt pins state
    INT2        = 1 << 1
    INT1        = 1 << 0

    ' Interrupts
    DRDY        = 1 << 7
    THSIGNED    = 1 << 6
    ZTHR        = 1 << 5
    YTHR        = 1 << 4
    XTHR        = 1 << 3
    TH1_PLS2    = %00 << 1                      ' INT1: Thresh, INT2: Pulse
    PLS1_TH2    = %01 << 1                      ' INT1: Pulse, INT2: Thresh
    SPLS1_DPLS2 = %10 << 1                      ' INT1: 1x Pulse, INT2: 2x Pulse
    INTPIN_INV  = 1


    SLAVE_WR    = core.SLAVE_ADDR
    SLAVE_RD    = core.SLAVE_ADDR|1


VAR

    long _ascl
    byte _addr_bits


OBJ

{ decide: Bytecode I2C engine, or PASM? Default is PASM if BC isn't specified }
#ifdef MMA7455_I2C_BC
    i2c:    "com.i2c.nocog"                     ' BC I2C engine
#else
    i2c:    "com.i2c"                           ' PASM I2C engine
#endif
    core:   "core.con.mma7455"                  ' HW-specific constants
    time:   "time"


PUB null()
' This is not a top-level object


PUB start(): status
' Start the driver using default I/O settings
    return startx(SCL, SDA, I2C_FREQ, I2C_ADDR)


PUB startx(SCL_PIN, SDA_PIN, I2C_HZ, ADDR_BITS): status
' Start the driver using custom settings
    if ( lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31) )
        if ( status := i2c.init(SCL_PIN, SDA_PIN, I2C_HZ) )
            time.msleep(1)
            _addr_bits := (ADDR_BITS << 1)
            if ( dev_id() == core.DEVID_RESP )
                return
    ' if this point is reached, something above failed
    ' Double check I/O pin assignments, connections, power
    ' Lastly - make sure you have at least one free core/cog
    return FALSE


PUB stop()
' Stop the driver
    i2c.deinit()


PUB preset_active()
' Enable sensor power and set full-scale range
    accel_opmode(MEASURE)
    accel_scale(2)


PUB preset_thresh_detect()
' Enable sensor power, set full-scale range, and set up
'   to trigger an interrupt on INT1 when an acceleration threshold is reached
    accel_opmode(LEVELDET)
    accel_scale(2)


PUB accel_bias(x, y, z) | tmp[2]
' Read accelerometer calibration offset values
'   x, y, z: pointers to copy offsets to
    readreg(core.XOFFL, 6, @tmp)
    long[x] := ( ( (tmp.word[X_AXIS] << 22) ~> 22) * 2)
    long[y] := ( ( (tmp.word[Y_AXIS] << 22) ~> 22) * 2)
    long[z] := ( ( (tmp.word[Z_AXIS] << 22) ~> 22) * 2)


PUB accel_data(ptr_x, ptr_y, ptr_z) | tmp[2]
' Reads the Accelerometer output registers
    longfill(@tmp, 0, 2)
    case _ascl
        2, 4:                                   ' 2g/4g (8-bit)
            tmp := readreg(core.XOUT8, 3)
            long[ptr_x] := ~tmp.byte[X_AXIS]
            long[ptr_y] := ~tmp.byte[Y_AXIS]
            long[ptr_z] := ~tmp.byte[Z_AXIS]
        8:                                      ' 8g (10-bit)
            readreg(core.XOUTL, 6, @tmp)
            ' extend sign
            long[ptr_x] := (tmp.word[X_AXIS] << 22) ~> 22
            long[ptr_y] := (tmp.word[Y_AXIS] << 22) ~> 22
            long[ptr_z] := (tmp.word[Z_AXIS] << 22) ~> 22


PUB accel_data_rate(r=-2): c
' Set accelerometer output data rate, in Hz
'   Valid values:
'       125, 250
'   Any other value polls the chip and returns the current setting
    c := readreg(core.CTL1)
    case r
        125, 250:
            r := lookdownz(r: 125, 250) << core.DFBW
            r := ((c & core.DFBW_MASK) | r)
            writereg(core.CTL1, r)
        other:
            c := ((c >> core.DFBW) & 1)
            return lookupz(c: 125, 250)


PUB accel_data_overrun(): o
' Flag indicating previously acquired data has been overwritten
'   Returns: TRUE (-1) if data has overflowed/been overwritten, FALSE otherwise
    o := readreg(core.STATUS)
    return ( ( (o >> core.DOVR) & 1) == 1)


PUB accel_data_rdy(): r
' Flag indicating data is ready
'   Returns: TRUE (-1) if data ready, FALSE otherwise
    r := readreg(core.STATUS)
    return ( (r & 1) == 1)


PUB accel_int(): i
' Accelerometer interrupt source(s)
'   Bits: 7..0
'       7: Level detection (X-axis)
'       6: Level detection (Y-axis)
'       5: Level detection (Z-axis)
'       4: Pulse detection (X-axis)
'       3: Pulse detection (Y-axis)
'       2: Pulse detection (Z-axis)
'       1: Interrupt assigned to INT2 asserted
'       0: Interrupt assigned to INT1 asserted
    return readreg(core.DETSRC)


PUB accel_int_clear(msk)
' Clear accelerometer interrupts
'   Bits: 1..0
'       1: Clear INT2 interrupt
'       0: Clear INT1 interrupt
'   Any other value is ignored
    case msk
        %00..%11:
            writereg(core.INTRST, msk)          ' clear interrupts
            writereg(core.INTRST, 0)            ' reset bits (not cleared
                                                '   automatically)


PUB accel_int_mask(msk=-2): c | drpd
' Set accelerometer interrupt mask
'   Bits 7..0:
'       7:
'           Data-ready on INT1 pin (doesn't affect accel_data_rdy())
'       6:
'           0: accel_int_set_thresh*() are unsigned (0g..+8g)
'           1: accel_int_set_thresh*() are signed (-8g..+8g)
'       5..3
'           5: Z-axis detection
'           4: Y-axis detection
'           3: X-axis detection
'       2..1  INT1                        INT2
'           %00:    Threshold detection         Pulse/Click/Tap detection
'           %01:    Pulse/Click/Tap detection   Threshold detection
'           %10:    Single pulse detection      Single/double pulse detection
'       0:
'           0: accel_int() behavior
'               INT1 bit indicates INT1 interrupt
'               INT2 bit indicates INT2 interrupt
'           1: accel_int() behavior
'               INT1 bit indicates INT2 interrupt
'               INT2 bit indicates INT1 interrupt
'   Any other value polls the chip and returns the current setting
    c := readreg(core.CTL1)
    drpd := readreg(core.MCTL)                  ' read data-ready enable bit
    case msk
        %0000_0000..%1111_1111:                 ' MSB is for DRPD, not DFBW
            msk ^= %00_111_000
            if (msk & %10000000)                ' if bit 7 is set,
                drpd &= core.DRPD_EN            ' make sure the data-ready
            else                                ' function is enabled
                drpd |= core.DRPD_DIS
            writereg(core.MCTL, drpd)
            msk &= core.INTMASK_BITS
            msk := ((c & core.INTMASK_MASK) | msk)
            writereg(core.CTL1, msk)
        other:
            c := (c & core.INTMASK_BITS) ^ core.ZYXDA_INV
            ' ignore all bits from the MCTL reg except the DRPD bit,
            ' invert it (because 0 is enabled, 1 is disabled),
            ' and place it in the MSB so it can be combined with the intmask
            drpd := (((drpd & core.DRPD_BIT) ^ core.DRPD_BIT) << 1)
            return (c | drpd)


PUB accel_int_set_thresh(thr)
' Set interrupt threshold
'   Valid values: 0..8_000000 (0..8g's; clamped to range)
    thr := ((0 #> thr <# 8_000000) / 62_500)
    writereg(core.LDTH, thr)


PUB accel_int_thresh_x(thr)
' Set interrupt threshold, X-axis
'   Valid values: 0..8_000000 (0..8g)
'   NOTE: Range is fixed at 0..8g, regardless of accel_scale() setting
'   NOTE: X, Y, Z axis are locked together (chip limitation);
'       separate X, Y, Z methods provided for API compatibility
    accel_int_set_thresh(thr)


PUB accel_int_thresh_y(thr)
' Set interrupt threshold, Y-axis
'   Any other value returns the current setting
'   NOTE: Range is fixed at 0..8g, regardless of accel_scale() setting
'   NOTE: X, Y, Z axis are locked together (chip limitation);
'       separate X, Y, Z methods provided for API compatibility
    accel_int_set_thresh(thr)


PUB accel_int_thresh_z(thr)
' Set interrupt threshold, Z-axis
'   Any other value returns the current setting
'   NOTE: Range is fixed at 0..8g, regardless of accel_scale() setting
'   NOTE: X, Y, Z axis are locked together (chip limitation);
'       separate X, Y, Z methods provided for API compatibility
    accel_int_set_thresh(thr)


PUB accel_int_thresh(): t
' Get interrupt threshold
    t := readreg(core.LDTH)
    return (~t * 62_500)                        ' convert to micro-g's


PUB accel_opmode(md=-2): c
' Set operating mode
'   Valid values:
'       STANDBY (%00): Standby
'       MEASURE (%01): Measurement mode
'       LEVELDET (%10): Level detection mode
'       PULSEDET (%11): Pulse detection mode
'   Any other value polls the chip and returns the current setting
    c := readreg(core.MCTL)
    case md
        STANDBY, MEASURE, LEVELDET, PULSEDET:
            md := ((c & core.MODE_MASK) | md)
            writereg(core.MCTL, md)
        other:
            return c & core.MODE_BITS


PUB accel_scale(s=-2): c | d
' Set measurement range of the accelerometer, in g's
'   Valid values: 2, 4, *8
'   Any other value polls the chip and returns the current setting
    c := readreg(core.MCTL)
    case s
        2, 4, 8:
            if ( s == 8 )
                d := 1024
            else
                d := 256
            _ares := (2_000000 * s) / d
            _ascl := s
            s := lookdownz(s: 8, 2, 4) << core.GLVL
            s := ((c & core.GLVL_MASK) | s)
            writereg(core.MCTL, s)
        other:
            c := (c >> core.GLVL) & core.GLVL_BITS
            return lookupz(c: 8, 2, 4)


PUB accel_self_test(st=-2): c
' Enable self-test
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
'   During self-test, the output data changes approximately as follows:
'       Z: +0.5g..+1.296g (+1.000g typ) (32..83LSB * 15625 micro-g per LSB)
    c := readreg(core.MCTL)
    case abs(st)
        0, 1:
            st := abs(st) << core.STON
            st := ( (c & core.STON_MASK) | st)
            writereg(core.MCTL, st)
        other:
            return ( ( (c >> core.STON) & 1) == 1)


PUB accel_set_bias(x, y, z)
' Write accelerometer calibration offset values
'   Valid values:
'       x, y, z:
'           -128..127 (2g or 4g scale)
'           -512..511 (8g scale)
'           (clamped to range)
    x := (-512 #> x <# 511) * -2
    y := (-512 #> y <# 511) * -2
    z := (-512 #> z <# 511) * -2
    writereg(core.XOFFL, x, 2)
    writereg(core.YOFFL, y, 2)
    writereg(core.ZOFFL, z, 2)


PUB dev_id(): id
' Get chip/device ID
'   Known values: $55
    return readreg(core.WHOAMI)


PRI readreg(reg_nr, len=1, p_dest=0): v | cmd_pkt
' Read value from register(s)
    if ( (reg_nr <> core.XOUTL) and (reg_nr <> core.XOFFL) )
        p_dest := @v

    cmd_pkt.byte[0] := (SLAVE_WR | _addr_bits)
    cmd_pkt.byte[1] := reg_nr
    i2c.start()
    i2c.wrblock_lsbf(@cmd_pkt, 2)

    i2c.start()
    i2c.write(SLAVE_RD | _addr_bits)
    i2c.rdblock_lsbf(p_dest, len, i2c.NAK)
    i2c.stop()


PRI writereg(reg_nr, val, len=1) | cmd_pkt
' Write value to register(s)
    cmd_pkt.byte[0] := (SLAVE_WR | _addr_bits)
    cmd_pkt.byte[1] := reg_nr
    i2c.start()
    i2c.wrblock_lsbf(@cmd_pkt, 2)
    i2c.wrblock_lsbf(@val, len)
    i2c.stop()


DAT
{
Copyright 2025 Jesse Burt

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
}

