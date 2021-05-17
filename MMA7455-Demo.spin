{
    --------------------------------------------
    Filename: MMA7455-Demo.spin
    Author: Jesse Burt
    Description: Demo of the MMA7455 driver
    Copyright (c) 2020
    Started Aug 28, 2020
    Updated Oct 31, 2020
    See end of file for terms of use.
    --------------------------------------------
}
CON

    _clkmode    = cfg#_clkmode
    _xinfreq    = cfg#_xinfreq

' -- User-modifiable constants
    LED         = cfg#LED1
    SER_BAUD    = 115_200

    SCL_PIN     = 28
    SDA_PIN     = 29
    I2C_HZ      = 400_000
' --

    DAT_X_COL   = 20
    DAT_Y_COL   = DAT_X_COL + 15
    DAT_Z_COL   = DAT_Y_COL + 15

    C           = 0
    F           = 1

OBJ

    cfg     : "core.con.boardcfg.flip"
    ser     : "com.serial.terminal.ansi"
    time    : "time"
    int     : "string.integer"
    accel   : "sensor.accel.3dof.mma7455.i2c"

PUB Main{} | dispmode

    setup{}
    accel.opmode(accel#MEASURE)
    accel.accelscale(4)
    ser.hidecursor{}
    dispmode := 0
    displaysettings{}
    repeat
        case ser.rxcheck{}
            "q", "Q":                                       ' Quit the demo
                ser.position(0, 17)
                ser.str(string("Halting"))
                accel.stop{}
                time.msleep(5)
                quit
            "c", "C":                                       ' Perform calibration
                calibrate{}
                displaysettings{}
            "r", "R":                                       ' Change display mode: raw/calculated
                ser.position(0, 14)
                repeat 2
                    ser.clearline{}
                    ser.newline{}
                dispmode ^= 1
        case dispmode
            0:
                ser.position(0, 14)
                accelraw{}
            1:
                ser.position(0, 14)
                accelcalc{}

    ser.showcursor{}
    repeat

PUB AccelCalc{} | ax, ay, az

'    repeat until accel.acceldataready{}
    accel.accelg(@ax, @ay, @az)
    ser.str(string("Accel micro-g: "))
    ser.position(DAT_X_COL, 14)
    decimal(ax, 1_000_000)
    ser.position(DAT_Y_COL, 14)
    decimal(ay, 1_000_000)
    ser.position(DAT_Z_COL, 14)
    decimal(az, 1_000_000)
    ser.clearline{}
    ser.newline{}

PUB AccelRaw{} | ax, ay, az

'    repeat until accel.acceldataready{}
    accel.acceldata(@ax, @ay, @az)
    ser.str(string("Accel raw: "))
    ser.position(DAT_X_COL, 14)
    ser.str(int.decpadded(ax, 7))
    ser.position(DAT_Y_COL, 14)
    ser.str(int.decpadded(ay, 7))
    ser.position(DAT_Z_COL, 14)
    ser.str(int.decpadded(az, 7))
    ser.clearline{}
    ser.newline{}

PUB Calibrate{}

    ser.position(0, 21)
    ser.str(string("Calibrating..."))
    accel.calibrateaccel{}
    ser.position(0, 21)
    ser.str(string("              "))

PUB DisplaySettings{} | axo, ayo, azo

    ser.position(0, 3)
    ser.str(string("AccelScale: "))
    ser.dec(accel.accelscale(-2))
    ser.newline{}

PUB Decimal(scaled, divisor) | whole[4], part[4], places, tmp, sign
' Display a scaled up number as a decimal
'   Scale it back down by divisor (e.g., 10, 100, 1000, etc)
    whole := scaled / divisor
    tmp := divisor
    places := 0
    part := 0
    sign := 0
    if scaled < 0
        sign := "-"
    else
        sign := " "

    repeat
        tmp /= 10
        places++
    until tmp == 1
    scaled //= divisor
    part := int.deczeroed(||(scaled), places)

    ser.char(sign)
    ser.dec(||(whole))
    ser.char(".")
    ser.str(part)

PUB Setup{}

    ser.start(SER_BAUD)
    time.msleep(30)
    ser.clear{}
    ser.strln(string("Serial terminal started"))
    if accel.startx(SCL_PIN, SDA_PIN, I2C_HZ)
        ser.str(string("MMA7455 driver started (I2C)"))
    else
        ser.str(string("MMA7455 driver failed to start - halting"))
        accel.stop{}
        time.msleep(5)
        repeat

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
