# mma7455-spin 
--------------

This is a P8X32A/Propeller driver object for the NXP MMA7455 3DoF accelerometer

## Salient Features

* I2C connection at up to 400kHz
* Read Device ID
* Read raw accelerometer data, or data in micro-g's
* Change operating mode (standby, measure, level detection, pulse detection)
* Data ready and overrun flags
* Perform calibration and store results in on-chip (volatile) offset registers

## Requirements

* P1/SPIN1: 1 extra core/cog for the PASM I2C driver

## Compiler Compatibility

* P1/SPIN1: OpenSpin (tested with 1.00.81)

## Limitations

* Very early in development - may malfunction, or outright fail to build

## TODO

- [ ] SPI driver variant
