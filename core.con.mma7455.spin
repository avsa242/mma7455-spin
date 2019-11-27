{
    --------------------------------------------
    Filename: core.con.mma7455.spin
    Author:
    Description:
    Copyright (c) 2019
    Started Nov 27, 2019
    Updated Nov 27, 2019
    See end of file for terms of use.
    --------------------------------------------
}

CON

    I2C_MAX_FREQ        = 400_000
    SLAVE_ADDR          = $1D << 1

' Register definitions
    XOUTL               = $00
    XOUTH               = $01
    YOUTL               = $02
    YOUTH               = $03
    ZOUTL               = $04
    ZOUTH               = $05
    XOUT8               = $06
    YOUT8               = $07
    ZOUT8               = $08
    STATUS              = $09
    DETSRC              = $0A
    TOUT                = $0B
' RESERVED - $0C
    I2CAD               = $0D
    USRINF              = $0E
    WHOAMI              = $0F
    XOFFL               = $10
    XOFFH               = $11
    YOFFL               = $12
    YOFFH               = $13
    ZOFFL               = $14
    ZOFFH               = $15
    MCTL                = $16
    INTRST              = $17
    CTL1                = $18
    CTL2                = $19
    LDTH                = $1A
    PDTH                = $1B
    PW                  = $1C
    LT                  = $1D
    TW                  = $1E
' RESERVED - $1F


PUB Null
'' This is not a top-level object
