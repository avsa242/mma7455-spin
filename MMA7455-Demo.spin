{
    --------------------------------------------
    Filename: MMA7455-Demo.spin
    Author: Jesse Burt
    Description: Simple demo for the MMA7455 driver
    Copyright (c) 2019
    Started Nov 27, 2019
    Updated Nov 27, 2019
    See end of file for terms of use.
    --------------------------------------------
}

CON

    _clkmode    = cfg#_clkmode
    _xinfreq    = cfg#_xinfreq

    LED         = cfg#LED1
    SCL_PIN     = 28
    SDA_PIN     = 29
    I2C_HZ      = 400_000

OBJ

    cfg     : "core.con.boardcfg.flip"
    ser     : "com.serial.terminal"
    time    : "time"
    int     : "string.integer"
    io      : "io"
    mma7455 : "sensor.3dof.accel.mma7455.i2c"

VAR

    byte _ser_cog

PUB Main | x, y, z, overflowed

    Setup
    mma7455.OpMode (mma7455#MEASURE)
    mma7455.AccelRange (8)

    ser.Str (string("Accel range: "))
    ser.Dec (mma7455.AccelRange (-2))
    repeat
        repeat until mma7455.DataReady                  ' Wait until a new set of data is ready

        if mma7455.DataOverflowed
            overflowed++

        mma7455.Accel (@x, @y, @z)                      ' Then read it into the local variables

        ser.Position (0, 5)                             ' and display
        ser.Str (string("X: "))
        ser.Str (int.DecPadded (x, 5))

        ser.Str (string("  Y: "))
        ser.Str (int.DecPadded (y, 5))

        ser.Str (string("  Z: "))
        ser.Str (int.DecPadded (z, 5))

        ser.Str (string("  Overflows: "))
        ser.Str (int.DecPadded (overflowed, 5))

    FlashLED (LED, 100)

PUB Setup

    repeat until _ser_cog := ser.Start (115_200)
    ser.Clear
    ser.Str(string("Serial terminal started", ser#NL))
    if mma7455.Startx (SCL_PIN, SDA_PIN, I2C_HZ)
        ser.Str(string("MMA7455 driver started", ser#NL))
    else
        ser.Str(string("MMA7455 driver failed to start - halting", ser#NL))
        mma7455.Stop
        time.MSleep (500)
        FlashLED (LED, 500)

PUB FlashLED(led_pin, delay_ms)

    io.Output (led_pin)
    repeat
        io.Toggle (led_pin)
        time.MSleep (delay_ms)

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
