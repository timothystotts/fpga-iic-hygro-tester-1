# fpga-iic-hygro-tester-1

FPGA IIC HYGRO Tester Version 1

by Timothy Stotts

Note that this project is deprecated. The most recent project, with wider
hardware support and occasional updates, is Version 3 and is located at:
[fpga-iic-hygro-tester-3](https://github.com/timothystotts/fpga-iic-hygro-tester-3)

## Description
A small FPGA project of different implementations for testing Temperature and Relative Humidity
readings of a I2C sensor.
The design targets the Digilent Inc. Arty-A7-100T FPGA development board containing a Xilinx Artix-7 FPGA.
Three peripherals are used: Digilent Inc. Pmod HYGRO, Digilent Inc. Pmod CLS., Digilent Inc. Pmod SSD.

The design is broken into two groupings.

The folder HYGRO-Tester-Design-AXI contains a Xilinx Vivado IP Integrator plus
Xilinx SDK design. A Microblaze soft CPU is instantiated to talk with board components,
a temperature and relative humidity sensor,
a 16x2 character LCD peripheral,
and a two-digit Seven Segment Display.
A Xilinx SDK project contains a very small Standalone program in C; drivers
for the peripherals, a main loop to operate and poll the sensor,
poll the switches and buttons,
update LCD, update 7SD, and color-mix RGB LEDs.

The folder HYGRO-Tester-Design-Verilog contains a Xilinx Vivado project with sources
containing only Verilog-2001 modules. Plain HDL without a soft CPU or C code is authored to
talk with board components,
a temperature and relative humidity sensor peripheral,
a 16x2 character LCD peripheral,
and a 2-digit 7-segment display.

These two groupings of design provide equivalent functionality, excepting that the HDL designs provide
additional animation effect of the board's three-emitter RGB LEDs. Both designs are in a prerelease
state and can be cloned or downloaded with the tag Hygro_Tester_Both_Prerelease_1A.

### Naming conventions notice
The Pmod CLS peripheral used in this project connects via a standard bus technology design called SPI.
The use of MOSI/MISO terminology is considered obsolete. COPI/CIPO is now used. The MOSI signal on a
controller can be replaced with the title 'COPI'. Master and Slave terms are now Controller and Peripheral.
Additional information can be found [here](https://www.oshwa.org/a-resolution-to-redefine-spi-signal-names).
The choice to use COPI and CIPO instead of SDO and SDI for single-direction bus signals is simple.
On a single peripheral bus with two data lines of fixed direction, the usage of the signal name
"SDO" is dependent on whether the Controller or the Peripheral is the chip being discussed;
whereas COPI gives the exact direction regardless of which chip is being discussed. The author
of this website agrees with the open source community that the removal of offensive language from
standard terminology in engineering is a priority.

### Project information document:
```
./HYGRO Sensor Readings Tester.pdf
```

[HYGRO Sensor Readings Tester info](https://github.com/timothystotts/fpga-iic-hygro-tester-1/blob/main/HYGRO%20Sensor%20Readings%20Tester.pdf)

### Diagrams design document:
```
./HYGRO-Tester-Design-Documents/HYGRO-Tester-Design-Diagrams.pdf
```

[HYGRO Tester Design Diagrams info](https://github.com/timothystotts/fpga-iic-hygro-tester-1/blob/main/HYGRO-Tester-Design-Documents/HYGRO-Tester-Design-Diagrams.pdf)

#### Target device assembly: Arty-A7-100T with Pmod HYGRO on test header, Pmod CLS on extension cable, Pmod SSD on extension cable
![Target device assembly](https://github.com/timothystotts/fpga-iic-hygro-tester-1/blob/main/HYGRO-Tester-Design-Documents/img_iic-hygro-tester-assembled-20200910_145526433.jpg)

#### Target device execution: Arty-A7-100T with Pmod HYGRO on test header, Pmod CLS on extension cable, Pmod SSD on extension cable
![Target device assembly executing](https://github.com/timothystotts/fpga-iic-hygro-tester-1/blob/main/HYGRO-Tester-Design-Documents/img_iic-hygro-tester-executing-a-20200910_145459654.jpg)

#### Block diagram architecture of the HDL designs:
![HYGRO Tester Architecture Diagram](https://github.com/timothystotts/fpga-iic-hygro-tester-1/blob/main/HYGRO-Tester-Design-Documents/HYGRO-Tester-Design-Diagrams-Architecture%201.svg)

#### Top Port diagram architecture of the HDL designs:
![HYGRO Tester Top Ports Diagram](https://github.com/timothystotts/fpga-iic-hygro-tester-1/blob/main/HYGRO-Tester-Design-Documents/HYGRO-Tester-Design-Diagrams-Top-Ports.svg)

#### LCD FSM diagram of the HDL designs:
![LCD FSM Diagram](https://github.com/timothystotts/fpga-iic-hygro-tester-1/blob/main/HYGRO-Tester-Design-Documents/HYGRO-Tester-Design-Diagrams-LCD-FSM.svg)

#### UART Feed FSM diagram of the HDL designs:
![UART Feed FSM Diagram](https://github.com/timothystotts/fpga-iic-hygro-tester-1/blob/main/HYGRO-Tester-Design-Documents/HYGRO-Tester-Design-Diagrams-UARTfeed.svg)

#### UART TX ONLY FSM diagram of the HDL designs:
![UART Feed FSM Diagram](https://github.com/timothystotts/fpga-iic-hygro-tester-1/blob/main/HYGRO-Tester-Design-Documents/HYGRO-Tester-Design-Diagrams-UART-Tx-FSM.svg)

#### 4-input Multi-Debouncer for 4 exclusve inputs, such as switches or buttons, of the HDL designs:
![4-bit Multi-Debouncer](https://github.com/timothystotts/fpga-iic-hygro-tester-1/blob/main/HYGRO-Tester-Design-Documents/HYGRO-Tester-Design-Diagrams-multi-debounce.svg)

#### HYGRO Custom Driver Ports diagram of the HDL designs:
![HYGRO Solo Driver Ports](https://github.com/timothystotts/fpga-iic-hygro-tester-1/blob/main/HYGRO-Tester-Design-Documents/HYGRO-Tester-Design-Diagrams-HYGRO-Ports.svg)

#### Pmod HYGRO IIC custom driver FSM for operating as a single setup and then poll once per second:
![HYGRO Custom Driver readings driver FSM](https://github.com/timothystotts/fpga-iic-hygro-tester-1/blob/main/HYGRO-Tester-Design-Documents/HYGRO-Tester-Design-Diagrams-HYGRO%20FSM.svg)

#### CLS Custom Driver Ports diagram of the HDL designs:
![CLS Custom Driver Ports](https://github.com/timothystotts/fpga-iic-hygro-tester-1/blob/main/HYGRO-Tester-Design-Documents/HYGRO-Tester-Design-Diagrams-CLS-ports.svg)

#### Generic Standard SPI Single Chip protocol bus driver, used by the ACL2 driver and the CLS driver
![Generic Standard SPI Single Chip bus driver](https://github.com/timothystotts/fpga-iic-hygro-tester-1/blob/main/HYGRO-Tester-Design-Documents/HYGRO-Tester-Design-Diagrams-SPI-generic-FSM.svg)

#### Pmod CLS Standard SPI custom driver FSM for operating the standard SPI driver to send text line refreshes to the ATmega48 microcontroller chip of the Pmod CLS:
![CLS Custom Driver readings driver FSM](https://github.com/timothystotts/fpga-iic-hygro-tester-1/blob/main/HYGRO-Tester-Design-Documents/HYGRO-Tester-Design-Diagrams-CLS-driver-FSM.svg)
