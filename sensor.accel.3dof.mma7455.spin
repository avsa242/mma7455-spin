{
    --------------------------------------------
    Filename: sensor.accel.3dof.mma7455.i2c.spin
    Author: Jesse Burt
    Description: Driver for the NXP/Freescale MMA7455 3-axis accelerometer
    Copyright (c) 2021
    Started Nov 27, 2019
    Updated Dec 28, 2021
    See end of file for terms of use.
    --------------------------------------------
}

CON

    SLAVE_WR    = core#SLAVE_ADDR
    SLAVE_RD    = core#SLAVE_ADDR|1

    DEF_SCL     = 28
    DEF_SDA     = 29
    DEF_HZ      = 100_000
    I2C_MAX_FREQ= core#I2C_MAX_FREQ

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

VAR

    long _ares, _ascl

OBJ

    i2c : "com.i2c"
    core: "core.con.mma7455"
    time: "time"

PUB Null{}
'This is not a top-level object

PUB Start{}: status
' Start using "standard" Propeller I2C pins and 100kHz
    return startx(DEF_SCL, DEF_SDA, DEF_HZ)

PUB Startx(SCL_PIN, SDA_PIN, I2C_HZ): status
' Start using custom settings
    if lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31) and {
}   I2C_HZ =< core#I2C_MAX_FREQ
        if (status := i2c.init(SCL_PIN, SDA_PIN, I2C_HZ))
            time.msleep(1)
            if i2c.present(SLAVE_WR)        ' check device bus presence
                if deviceid{} == core#DEVID_RESP
                    return
    ' if this point is reached, something above failed
    ' Double check I/O pin assignments, connections, power
    ' Lastly - make sure you have at least one free core/cog
    return FALSE

PUB Stop{}

    i2c.deinit{}

PUB Preset_Active{}
' Enable sensor power and set full-scale range
    accelopmode(MEASURE)
    accelscale(2)

PUB Preset_ThreshDetect{}
' Enable sensor power, set full-scale range, and set up
'   to trigger an interrupt on INT1 when an acceleration threshold is reached
    accelopmode(LEVELDET)
    accelscale(2)

PUB AccelBias(bias_x, bias_y, bias_z, rw) | tmp[2]
' Read or write/manually set accelerometer calibration offset values
'   Valid values:
'       rw:
'           R (0), W (1)
'       bias_x, bias_y, bias_z:
'           -128..127 (2g or 4g scale)
'           -512..511 (8g scale)
'   NOTE: When rw is set to READ, bias_x, bias_y and bias_z must be addresses
'       of respective variables to hold the returned calibration offset values.
    case rw
        R:
            readreg(core#XOFFL, 6, @tmp)
            long[bias_x] := (((tmp.word[X_AXIS] << 22) ~> 22) * 2)
            long[bias_y] := (((tmp.word[Y_AXIS] << 22) ~> 22) * 2)
            long[bias_z] := (((tmp.word[Z_AXIS] << 22) ~> 22) * 2)
            return
        W:
            case bias_x
                -512..511:
                    bias_x *= 2
                other:
                    return                      ' out of range
            case bias_y
                -512..511:
                    bias_y *= 2
                other:
                    return                      ' out of range
            case bias_z
                -512..511:
                    bias_z *= 2
                other:
                    return                      ' out of range
            writereg(core#XOFFL, 2, @bias_x)
            writereg(core#YOFFL, 2, @bias_y)
            writereg(core#ZOFFL, 2, @bias_z)

PUB AccelData(ptr_x, ptr_y, ptr_z) | tmp[2]
' Reads the Accelerometer output registers
    longfill(@tmp, 0, 2)
    case _ascl
        2, 4:                                   ' 2g/4g (8-bit)
            readreg(core#XOUT8, 3, @tmp)
            long[ptr_x] := ~tmp.byte[X_AXIS]
            long[ptr_y] := ~tmp.byte[Y_AXIS]
            long[ptr_z] := ~tmp.byte[Z_AXIS]
        8:                                      ' 8g (10-bit)
            readreg(core#XOUTL, 6, @tmp)
            ' extend sign
            long[ptr_x] := (tmp.word[X_AXIS] << 22) ~> 22
            long[ptr_y] := (tmp.word[Y_AXIS] << 22) ~> 22
            long[ptr_z] := (tmp.word[Z_AXIS] << 22) ~> 22

PUB AccelDataRate(rate): curr_rate
' Set accelerometer output data rate, in Hz
'   Valid values:
'       125, 250
'   Any other value polls the chip and returns the current setting
    curr_rate := 0
    readreg(core#CTL1, 1, @curr_rate)
    case rate
        125, 250:
            rate := lookdownz(rate: 125, 250) << core#DFBW
        other:
            curr_rate := ((curr_rate >> core#DFBW) & 1)
            return lookupz(curr_rate: 125, 250)

    rate := ((curr_rate & core#DFBW_MASK) | rate)
    writereg(core#CTL1, 1, @rate)

PUB AccelDataOverrun{}: flag
' Flag indicating previously acquired data has been overwritten
'   Returns: TRUE (-1) if data has overflowed/been overwritten, FALSE otherwise
    readreg(core#STATUS, 1, @flag)
    return (((flag >> core#DOVR) & 1) == 1)

PUB AccelDataReady{}: flag
' Flag indicating data is ready
'   Returns: TRUE (-1) if data ready, FALSE otherwise
    readreg(core#STATUS, 1, @flag)
    return ((flag & 1) == 1)

PUB AccelG(ptr_x, ptr_y, ptr_z) | tmpx, tmpy, tmpz
' Reads the Accelerometer output registers and scales the outputs to micro-g's (1_000_000 = 1.000000 g = 9.8 m/s/s)
    acceldata(@tmpx, @tmpy, @tmpz)
    long[ptr_x] := tmpx * _ares
    long[ptr_y] := tmpy * _ares
    long[ptr_z] := tmpz * _ares

PUB AccelIntClear(mask)
' Clear accelerometer interrupts
'   Bits: 1..0
'       1: Clear INT2 interrupt
'       0: Clear INT1 interrupt
'   Any other value is ignored
    case mask
        %00..%11:
            writereg(core#INTRST, 1, @mask)     ' clear interrupts
            mask := 0
            writereg(core#INTRST, 1, @mask)     ' reset bits (not cleared
        other:                                  '   automatically)
            result := 0
            readreg(core#INTRST, 1, @result)
            return

PUB AccelInt{}: int_src
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
    int_src := 0
    readreg(core#DETSRC, 1, @int_src)

PUB AccelIntMask(mask): curr_mask | drpd
' Set accelerometer interrupt mask
'   Bits 7..0:
'       7:
'           Data-ready on INT1 pin (doesn't affect AccelDataReady())
'       6:
'           0: AccelIntThresh*() are unsigned (0g..+8g)
'           1: AccelIntThresh*() are signed (-8g..+8g)
'       5..3
'           5: Z-axis detection
'           4: Y-axis detection
'           3: X-axis detection
'       2..1  INT1                        INT2
'           %00:    Threshold detection         Pulse/Click/Tap detection
'           %01:    Pulse/Click/Tap detection   Threshold detection
'           %10:    Single pulse detection      Single/double pulse detection
'       0:
'           0: AccelInt() behavior
'               INT1 bit indicates INT1 interrupt
'               INT2 bit indicates INT2 interrupt
'           1: AccelInt() behavior
'               INT1 bit indicates INT2 interrupt
'               INT2 bit indicates INT1 interrupt
'   Any other value polls the chip and returns the current setting
    curr_mask := 0
    readreg(core#CTL1, 1, @curr_mask)
    drpd := 0
    readreg(core#MCTL, 1, @drpd)                ' read data-ready enable bit
    case mask
        %0000_0000..%1111_1111:                 ' MSB is for DRPD, not DFBW
            mask ^= %00_111_000
        other:
            curr_mask := (curr_mask & core#INTMASK_BITS) ^ core#ZYXDA_INV
            ' ignore all bits from the MCTL reg except the DRPD bit,
            ' invert it (because 0 is enabled, 1 is disabled),
            ' and place it in the MSB so it can be combined with the intmask
            drpd := (((drpd & core#DRPD_BIT) ^ core#DRPD_BIT) << 1)
            return (curr_mask | drpd)

    if (mask & %10000000)                       ' if bit 7 is set,
        drpd &= core#DRPD_EN                    ' make sure the data-ready
    else                                        ' function is enabled
        drpd |= core#DRPD_DIS
    writereg(core#MCTL, 1, @drpd)
    mask &= core#INTMASK_BITS
    mask := ((curr_mask & core#INTMASK_MASK) | mask)
    writereg(core#CTL1, 1, @mask)

PUB AccelIntThreshX(thresh): curr_thr
' Set interrupt threshold, X-axis
'   Valid values: 0..8_000000 (0..8g)
'   Any other value returns the current setting
'   NOTE: Range is fixed at 0..8g, regardless of AccelScale() setting
'   NOTE: X, Y, Z axis are locked together (chip limitation);
'       separate X, Y, Z methods provided for API compatibility
    return accelintthresh(thresh)

PUB AccelIntThreshY(thresh): curr_thr
' Set interrupt threshold, Y-axis
'   Valid values: 0..8_000000 (0..8g)
'   Any other value returns the current setting
'   NOTE: Range is fixed at 0..8g, regardless of AccelScale() setting
'   NOTE: X, Y, Z axis are locked together (chip limitation);
    return accelintthresh(thresh)

PUB AccelIntThreshZ(thresh): curr_thr
' Set interrupt threshold, Z-axis
'   Valid values: 0..8_000000 (0..8g)
'   Any other value returns the current setting
'   NOTE: Range is fixed at 0..8g, regardless of AccelScale() setting
'   NOTE: X, Y, Z axis are locked together (chip limitation);
    return accelintthresh(thresh)

PRI accelIntThresh(thresh): curr_thr
' Set interrupt threshold register
    case thresh
        0..8_000000:                            ' range is fixed 0..8g
            thresh /= 62_500                    ' convert to reg range (s8/u8)
            writereg(core#LDTH, 1, @thresh)
        other:
            curr_thr := 0
            readreg(core#LDTH, 1, @curr_thr)
            return (~curr_thr * 62_500)         ' convert to micro-g's

PUB AccelOpMode(mode) | curr_mode
' Set operating mode
'   Valid values:
'       STANDBY (%00): Standby
'       MEASURE (%01): Measurement mode
'       LEVELDET (%10): Level detection mode
'       PULSEDET (%11): Pulse detection mode
'   Any other value polls the chip and returns the current setting
    curr_mode := 0
    readreg(core#MCTL, 1, @curr_mode)
    case mode
        STANDBY, MEASURE, LEVELDET, PULSEDET:
        other:
            return curr_mode & core#MODE_BITS

    mode := ((curr_mode & core#MODE_MASK) | mode)
    writereg(core#MCTL, 1, @mode)

PUB AccelScale(scale): curr_scl
' Set measurement range of the accelerometer, in g's
'   Valid values: 2, 4, *8
'   Any other value polls the chip and returns the current setting
    curr_scl := 0
    readreg(core#MCTL, 1, @curr_scl)
    case scale
        2, 4:
            _ares := (2_000000 * scale) / 256   ' 8-bit output
        8:
            _ares := (2_000000 * scale) / 1024  ' 10-bit output
        other:
            curr_scl := (curr_scl >> core#GLVL) & core#GLVL_BITS
            return lookupz(curr_scl: 8, 2, 4)

    _ascl := scale
    scale := lookdownz(scale: 8, 2, 4) << core#GLVL
    scale := ((curr_scl & core#GLVL_MASK) | scale)
    writereg(core#MCTL, 1, @scale)

PUB AccelSelfTest(state) | curr_state
' Enable self-test
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
'   During self-test, the output data changes approximately as follows:
'       Z: +0.5g..+1.296g (+1.000g typ) (32..83LSB * 15625 micro-g per LSB)
    curr_state := 0
    readreg(core#MCTL, 1, @curr_state)
    case ||(state)
        0, 1:
            state := ||(state) << core#STON
        other:
            return (((curr_state >> core#STON) & 1) == 1)

    state := ((curr_state & core#STON_MASK) | state)
    writereg(core#MCTL, 1, @state)

PUB CalibrateAccel{} | acceltmp[ACCEL_DOF], axis, x, y, z, samples, scale_orig, drate_orig
' Calibrate the accelerometer
    longfill(@acceltmp, 0, 10)                  ' init variables to 0
    drate_orig := acceldatarate(-2)             ' store user-set data rate
    scale_orig := accelscale(-2)                '   and scale

    accelbias(0, 0, 0, W)                       ' clear existing bias offsets

    acceldatarate(CAL_XL_DR)                    ' set data rate and scale to
    accelscale(CAL_XL_SCL)                      '   device-specific settings
    samples := CAL_XL_DR                        ' samples = DR for approx 1sec
                                                '   worth of data
    repeat samples
        repeat until acceldataready{}
        acceldata(@x, @y, @z)                   ' throw out first set of samples

    repeat samples
        repeat until acceldataready{}
        acceldata(@x, @y, @z)                   ' accumulate samples to be
        acceltmp[X_AXIS] -= x                   '   averaged
        acceltmp[Y_AXIS] -= y
        acceltmp[Z_AXIS] -= z - (1_000_000 / _ares)

    ' write the updated offsets
    accelbias(acceltmp[X_AXIS] / samples, acceltmp[Y_AXIS] / samples, {
}   acceltmp[Z_AXIS] / samples, W)

    acceldatarate(drate_orig)                   ' restore user settings
    accelscale(scale_orig)

PUB DeviceID{}
' Get chip/device ID
'   Known values: $55
    readreg(core#WHOAMI, 1, @result)

PRI readReg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
' Read nr_bytes from slave device into ptr_buff
    case reg_nr
        $00..$0B, $0D..$1E:
            cmd_pkt.byte[0] := SLAVE_WR
            cmd_pkt.byte[1] := reg_nr
            i2c.start{}
            i2c.wrblock_lsbf(@cmd_pkt, 2)

            i2c.start{}
            i2c.write(SLAVE_RD)
            i2c.rdblock_lsbf(ptr_buff, nr_bytes, TRUE)
            i2c.stop{}
        other:
            return

PRI writeReg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
' Write nr_bytes from ptr_buff to slave device
    case reg_nr
        $10..$1E:
            cmd_pkt.byte[0] := SLAVE_WR
            cmd_pkt.byte[1] := reg_nr
            i2c.start{}
            i2c.wrblock_lsbf(@cmd_pkt, 2)
            i2c.wrblock_lsbf(ptr_buff, nr_bytes)
            i2c.stop{}
        other:
            return

DAT
{
    --------------------------------------------------------------------------------------------------------
    TERMS OF USE: MIT License

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
    associated documentation files (the "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
    following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial
    portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
    LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    --------------------------------------------------------------------------------------------------------
}