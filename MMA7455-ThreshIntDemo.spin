{
    --------------------------------------------
    Filename: MMA7455-ThreshIntDemo.spin
    Author: Jesse Burt
    Description: Demo of the MMA7455 driver
        Threshold interrupt functionality
    Copyright (c) 2022
    Started Dec 30, 2021
    Updated Oct 1, 2022
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
    I2C_FREQ    = 400_000
    ADDR_BITS   = 0

    INT1        = 24
' --

    DAT_X_COL   = 20
    DAT_Y_COL   = DAT_X_COL + 15
    DAT_Z_COL   = DAT_Y_COL + 15

OBJ

    cfg     : "core.con.boardcfg.flip"
    ser     : "com.serial.terminal.ansi"
    time    : "time"
    accel   : "sensor.accel.3dof.mma7455"

VAR

    long _isr_stack[50]                         ' stack for ISR core
    long _intflag                               ' interrupt flag

PUB main{}

    setup{}

    accel.preset_thresh_detect{}                ' set up for accel threshold
                                                '   detection

    accel.accel_int_clr(accel#INT1 | accel#INT2)' clear INT1 and INT2

    ' Set threshold to 1.0g, and enable detection on X axis only
    ' NOTE: Though there are threshold setting methods for all three
    '   axes, they are locked together (chip limitation). This is done
    '   for API-compatibility with other chips that have the ability to
    '   set independent thresholds.
    ' NOTE: The full-scale range of the threshold setting is 8g's,
    '   regardless of what accel.accel_scale() is set to.
    accel.accel_int_set_thresh(1_000000)
    accel.accel_int_mask(accel#XTHR)

    repeat
        ser.position(0, 3)
        show_accel_data{}
        if (_intflag)
            ser.position(0, 5)
            ser.strln(string("Interrupt"))
            repeat until ser.charin{}
            accel.accel_int_clr(%11)            ' must clear interrupts
            ser.position(0, 5)
            ser.clearline{}
        if (ser.rxcheck{} == "c")               ' press the 'c' key in the demo
            cal_accel{}                         ' to calibrate sensor offsets

PRI cog_isr{}
' Interrupt service routine
    dira[INT1] := 0                             ' INT1 as input
    repeat
        waitpeq(|< INT1, |< INT1, 0)            ' wait for INT1 (active low)
        _intflag := 1                           '   set flag
        waitpne(|< INT1, |< INT1, 0)            ' now wait for it to clear
        _intflag := 0                           '   clear flag

PUB setup{}

    ser.start(SER_BAUD)
    time.msleep(30)
    ser.clear{}
    ser.strln(string("Serial terminal started"))

    if accel.startx(SCL_PIN, SDA_PIN, I2C_FREQ, ADDR_BITS)
        ser.strln(string("MMA7455 driver started (I2C)"))
    else
        ser.strln(string("MMA7455 driver failed to start - halting"))
        repeat

    cognew(cog_isr{}, @_isr_stack)                    ' start ISR in another core

#include "acceldemo.common.spinh"

DAT
{
Copyright 2022 Jesse Burt

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

