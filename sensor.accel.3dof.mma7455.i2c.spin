{
    --------------------------------------------
    Filename: sensor.accel.3dof.mma7455.i2c.spin
    Author: Jesse Burt
    Description: Driver for the NXP/Freescale MMA7455 3-axis accelerometer
    Copyright (c) 2021
    Started Nov 27, 2019
    Updated Jan 1, 2021
    See end of file for terms of use.
    --------------------------------------------
}

CON

    SLAVE_WR          = core#SLAVE_ADDR
    SLAVE_RD          = core#SLAVE_ADDR|1

    DEF_SCL           = 28
    DEF_SDA           = 29
    DEF_HZ            = 100_000
    I2C_MAX_FREQ      = core#I2C_MAX_FREQ

' Indicate to user apps how many Degrees of Freedom each sub-sensor has
'   (also imply whether or not it has a particular sensor)
    ACCEL_DOF           = 3
    GYRO_DOF            = 0
    MAG_DOF             = 0
    BARO_DOF            = 0
    DOF                 = ACCEL_DOF + GYRO_DOF + MAG_DOF + BARO_DOF

'   Operating modes
    #0, STANDBY, MEASURE, LEVELDET, PULSEDET

VAR

    long _ares

OBJ

    i2c : "com.i2c"
    core: "core.con.mma7455.spin"
    time: "time"

PUB Null{}
'This is not a top-level object

PUB Start{}: okay
' Start using "standard" Propeller I2C pins and 100kHz
    okay := startx(DEF_SCL, DEF_SDA, DEF_HZ)

PUB Startx(SCL_PIN, SDA_PIN, I2C_HZ): okay
' Start using custom settings
    if lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31)
        if I2C_HZ =< core#I2C_MAX_FREQ
            if okay := i2c.setupx(SCL_PIN, SDA_PIN, I2C_HZ)
                time.msleep(1)
                if i2c.present(SLAVE_WR)        ' check device bus presence
                    if deviceid{} == core#DEVID_RESP
                        return okay

    return FALSE                                ' something above failed

PUB Stop{}

    i2c.terminate{}

PUB AccelData(ptr_x, ptr_y, ptr_z) | tmp[2]
' Reads the Accelerometer output registers
    bytefill(@tmp, 0, 8)
    readreg(core#XOUTL, 6, @tmp)

    long[ptr_x] := tmp.word[0]
    long[ptr_y] := tmp.word[1]
    long[ptr_z] := tmp.word[2]

    if long[ptr_x] > 511
        long[ptr_x] := long[ptr_x]-1024
    if long[ptr_y] > 511
        long[ptr_y] := long[ptr_y]-1024
    if long[ptr_z] > 511
        long[ptr_z] := long[ptr_z]-1024

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

PUB AccelScale(g) | tmp
' Set measurement range of the accelerometer, in g's
'   Valid values: 2, 4, *8
'   Any other value polls the chip and returns the current setting
    tmp := 0
    readreg(core#MCTL, 1, @tmp)
    case g
        2, 4, 8:
            g := lookdownz(g: 8, 2, 4)
            _ares := (2_000000 * lookupz(g: 8, 2, 4)) / 1024     '/1024 = for 10-bit output
            g <<= core#GLVL
        other:
            tmp >>= core#GLVL
            tmp &= core#GLVL_BITS
            result := lookupz(tmp: 8, 2, 4)
            return

    tmp &= core#GLVL_MASK
    tmp := (tmp | g)
    writereg(core#MCTL, 1, @tmp)

PUB AccelSelfTest(enabled) | tmp
' Enable self-test
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
'   NOTE: The datasheet specifies the Z-axis should read between 32 and 83 (64 typ) when the self-test is enabled
    tmp := 0
    readreg(core#MCTL, 1, @tmp)
    case ||(enabled)
        0, 1:
            enabled := ||(enabled) << core#STON
        other:
            tmp >>= core#STON
            return ((tmp & 1) == 1)

    tmp &= core#STON_MASK
    tmp := (tmp | enabled)
    writereg(core#MCTL, 1, @tmp)

PUB Calibrate{} | tmpx, tmpy, tmpz
' Calibrate the accelerometer
'   NOTE: The accelerometer must be oriented with the package top facing up for this method to be successful
    repeat 3
        AccelData(@tmpx, @tmpy, @tmpz)
        tmpx += 2 * -tmpx
        tmpy += 2 * -tmpy
        tmpz += 2 * -(tmpz-(_ares/1000))

    writereg(core#XOFFL, 2, @tmpx)
    writereg(core#YOFFL, 2, @tmpy)
    writereg(core#ZOFFL, 2, @tmpz)
    time.msleep(200)

PUB DeviceID{}
' Get chip/device ID
'   Known values: $55
    readreg(core#WHOAMI, 1, @result)

PUB OpMode(mode) | tmp
' Set operating mode
'   Valid values:
'       STANDBY (%00): Standby
'       MEASURE (%01): Measurement mode
'       LEVELDET (%10): Level detection mode
'       PULSEDET (%11): Pulse detection mode
'   Any other value polls the chip and returns the current setting
    tmp := 0
    readreg(core#MCTL, 1, @tmp)
    case mode
        STANDBY, MEASURE, LEVELDET, PULSEDET:
        other:
            result := tmp & core#MODE_BITS
            return

    tmp &= core#MODE_MASK
    tmp := (tmp | mode)
    writereg(core#MCTL, 1, @tmp)

PRI readReg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt, tmp
' Read nr_bytes from slave device into ptr_buff
    case reg_nr
        $00..$0B, $0D..$1E:
            cmd_pkt.byte[0] := SLAVE_WR
            cmd_pkt.byte[1] := reg_nr
            i2c.start{}
            i2c.wr_block(@cmd_pkt, 2)

            i2c.start{}
            i2c.write(SLAVE_RD)
            i2c.rd_block(ptr_buff, nr_bytes, TRUE)
            i2c.stop{}
        other:
            return

PRI writeReg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt, tmp
' Write nr_bytes from ptr_buff to slave device
    case reg_nr
        $10..$1E:
            cmd_pkt.byte[0] := SLAVE_WR
            cmd_pkt.byte[1] := reg_nr
            i2c.start{}
            i2c.wr_block(@cmd_pkt, 2)
            repeat tmp from 0 to nr_bytes-1
                i2c.write(byte[ptr_buff][tmp])
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
