{
    --------------------------------------------
    Filename: MMA7455-ThreshIntDemo.spin
    Author: Jesse Burt
    Description: Demo of the MMA7455 driver
        Threshold interrupt functionality
    Copyright (c) 2021
    Started Dec 30, 2021
    Updated Dec 30, 2021
    See end of file for terms of use.
    --------------------------------------------
}

CON

    _clkmode    = cfg#_clkmode
    _xinfreq    = cfg#_xinfreq

' -- User-modifiable constants
    LED         = cfg#LED1
    SER_BAUD    = 115_200

    SCL_PIN     = 28                            ' I2C
    SDA_PIN     = 29                            ' I2C
    I2C_HZ      = 400_000                       ' I2C

    INT1        = 24
' --

    DAT_X_COL   = 20
    DAT_Y_COL   = DAT_X_COL + 15
    DAT_Z_COL   = DAT_Y_COL + 15

OBJ

    cfg     : "core.con.boardcfg.flip"
    ser     : "com.serial.terminal.ansi"
    time    : "time"
    int     : "string.integer"
    accel   : "sensor.accel.3dof.mma7455.i2c"

VAR

    long _isr_stack[50]                         ' stack for ISR core
    long _intflag                               ' interrupt flag

PUB Main{}

    setup{}

    accel.preset_threshdetect{}                 ' set up for accel threshold
                                                '   detection

    accel.accelintclear(accel#INT1 | accel#INT2)' clear INT1 and INT2

    ' Set threshold to 1.0g, and enable detection on X axis only
    ' NOTE: Though there are threshold setting methods for all three
    '   axes, they are locked together (chip limitation). This is done
    '   for API-compatibility with other chips that have the ability to
    '   set independent thresholds.
    ' NOTE: The full-scale range of the threshold setting is 8g's,
    '   regardless of what AccelScale() is set to.
    accel.accelintthreshz(1_000000)
    accel.accelintmask(accel#XTHR)

    repeat
        ser.position(0, 3)
        accelcalc{}
        if _intflag
            ser.position(0, 5)
            ser.strln(string("Interrupt"))
            repeat until ser.charin{}
            accel.accelintclear(%11)            ' must clear interrupts
            ser.position(0, 5)
            ser.clearline{}
        if ser.rxcheck{} == "c"                 ' press the 'c' key in the demo
            calibrate{}                         ' to calibrate sensor offsets

PUB AccelCalc{} | ax, ay, az

    repeat until accel.acceldataready{}         ' wait for new sensor data set
    accel.accelg(@ax, @ay, @az)                 ' read calculated sensor data
    ser.str(string("Accel (g):"))
    ser.positionx(DAT_X_COL)
    decimal(ax, 1000000)                        ' data is in micro-g's; display
    ser.positionx(DAT_Y_COL)                    ' it as if it were a float
    decimal(ay, 1000000)
    ser.positionx(DAT_Z_COL)
    decimal(az, 1000000)
    ser.clearline{}
    ser.newline{}

PUB Calibrate{}

    ser.position(0, 7)
    ser.str(string("Calibrating..."))
    accel.calibrateaccel{}
    ser.positionx(0)
    ser.clearline{}

PRI Decimal(scaled, divisor) | whole[4], part[4], places, tmp, sign
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
    ser.chars(" ", 5)

PRI ISR{}
' Interrupt service routine
    dira[INT1] := 0                             ' INT1 as input
    repeat
        waitpeq(|< INT1, |< INT1, 0)            ' wait for INT1 (active low)
        _intflag := 1                           '   set flag
        waitpne(|< INT1, |< INT1, 0)            ' now wait for it to clear
        _intflag := 0                           '   clear flag

PUB Setup{}

    ser.start(SER_BAUD)
    time.msleep(30)
    ser.clear{}
    ser.strln(string("Serial terminal started"))

    if accel.startx(SCL_PIN, SDA_PIN, I2C_HZ)
        ser.strln(string("MMA7455 driver started (I2C)"))
    else
        ser.strln(string("MMA7455 driver failed to start - halting"))
        repeat

    cognew(isr, @_isr_stack)                    ' start ISR in another core

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
