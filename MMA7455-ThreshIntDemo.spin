{
---------------------------------------------------------------------------------------------------
    Filename:       MMA7455-ThreshIntDemo.spin
    Description:    Demo of the MMA7455 driver
        * Threshold interrupt functionality
    Author:         Jesse Burt
    Started:        Dec 30, 2021
    Updated:        Jun 23, 2024
    Copyright (c) 2024 - See end of file for terms of use.
---------------------------------------------------------------------------------------------------
}

' Uncomment the following two lines to use the bytecode-based I2C engine
'#define MMA7455_I2C_BC
'#pragma exportdef(MMA7455_I2C_BC)


CON

    _clkmode    = cfg._clkmode
    _xinfreq    = cfg._xinfreq

' -- User-modifiable constants
    INT1        = 24
' --


OBJ

    cfg:    "boardcfg.flip"
    time:   "time"
    ser:    "com.serial.terminal.ansi" | SER_BAUD=115_200
    sensor: "sensor.accel.3dof.mma7455" | SCL=28, SDA=29, I2C_FREQ=400_000, I2C_ADDR=0


VAR

    long _isr_stack[50]                         ' stack for ISR core
    long _intflag                               ' interrupt flag


PUB main()

    setup()

    sensor.preset_thresh_detect()                ' set up for accel threshold
                                                '   detection

    sensor.accel_int_clear(sensor.INT1 | sensor.INT2)' clear INT1 and INT2

    ' Set threshold to 1.0g, and enable detection on X axis only
    ' NOTE: Though there are threshold setting methods for all three
    '   axes, they are locked together (chip limitation). This is done
    '   for API-compatibility with other chips that have the ability to
    '   set independent thresholds.
    ' NOTE: The full-scale range of the threshold setting is 8g's,
    '   regardless of what sensor.accel_scale() is set to.
    sensor.accel_int_set_thresh(1_000000)
    sensor.accel_int_mask(sensor.XTHR)

    repeat
        ser.pos_xy(0, 3)
        show_accel_data()
        if ( _intflag )
            ser.pos_xy(0, 5)
            ser.strln(@"Interrupt")
            ser.getchar()                       ' wait for keypress
            sensor.accel_int_clear(%11)         ' must clear interrupts
            ser.pos_xy(0, 5)
            ser.clear_line()
        if ( ser.getchar_noblock() == "c" )     ' press the 'c' key in the demo
            cal_accel()                         ' to calibrate sensor offsets


PRI cog_isr()
' Interrupt service routine
    dira[INT1] := 0                             ' INT1 as input
    repeat
        waitpeq(|< INT1, |< INT1, 0)            ' wait for INT1 (active low)
        _intflag := 1                           '   set flag
        waitpne(|< INT1, |< INT1, 0)            ' now wait for it to clear
        _intflag := 0                           '   clear flag


PUB setup()

    ser.start()
    time.msleep(30)
    ser.clear()
    ser.strln(@"Serial terminal started")

    if ( sensor.start() )
        ser.strln(@"MMA7455 driver started (I2C)")
    else
        ser.strln(@"MMA7455 driver failed to start - halting")
        repeat

    cognew(cog_isr(), @_isr_stack)              ' start ISR in another core

#include "acceldemo.common.spinh"               ' use code common to all accelerometer demos

DAT
{
Copyright 2024 Jesse Burt

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

