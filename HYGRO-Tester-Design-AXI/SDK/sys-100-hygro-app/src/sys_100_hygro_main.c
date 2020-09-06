/*------------------------------------------------------------------------------
-- MIT License
--
-- Copyright (c) 2020 Timothy Stotts
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
------------------------------------------------------------------------------*/
/**-----------------------------------------------------------------------------
 * @file sys_100_hygro_main.c
 *
 * @brief A SoPC top-level design with Pmod HYGRO sensor reading and display.
 * This design operates the Pmod HYGRO to read sensor values, and then outputs
 * display indications and values on the Pmod SSD, Pmod CLS, and board LEDs.
 *
 * @author
 * Timothy Stotts (timothystotts08@gmail.com)
 *
 * @copyright
 * (c) 2020 Copyright Timothy Stotts
 *
 * This program is free software; distributed under the terms of the MIT
 * License.
------------------------------------------------------------------------------*/

#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "xgpio.h"
#include "PmodCLS.h"
#include "PmodHYGRO.h"
#include "MuxSSD.h"
#include "led_pwm.h"

/* Global constants */
#define USERIO_DEVICE_ID 0
#define SWTCHS_SWS_MASK 0x0F
#define SWTCH_SW_CHANNEL 1
#define SWTCH0_MASK 0x01
#define SWTCH1_MASK 0x02
#define SWTCH2_MASK 0x04
#define SWTCH3_MASK 0x08
#define BTNS_SWS_MASK 0x0F
#define BTNS_SW_CHANNEL 2
#define BTN0_MASK 0x01
#define BTN1_MASK 0x02
#define BTN2_MASK 0x04
#define BTN3_MASK 0x08

/* Global constants */
#define CAPTURED_STRING_LENGTH 11

/* Global types */
typedef struct T_EXPERIMENT_DATA_TAG
{
	/* Driver objects */
	XGpio axGpio;
	PmodCLS clsDevice;
	PmodHYGRO hygroDevice;
	u32 ssdDigitRight;
	u32 ssdDigitLeft;
	/* LED driver palettes stored */
	t_rgb_led_palette_silk ledUpdate[8];
	/* GPIO reading values at this point in the execution */
	u32 switchesRead;
	u32 buttonsRead;
	u32 switchesReadPrev;
	u32 buttonsReadPrev;
	/* HYGRO Sensor data read */
	float temp_degc;
	float temp_degf;
	float hum_perrh;
	/* CLS display text lines */
	char szInfo1[32];
	char szInfo2[32];
} t_experiment_data;

/* Function prototypes */
static void Experiment_LEDsInitialize(t_experiment_data* expData);
static void Experiment_UserIOInitialize(t_experiment_data* expData);
static void Experiment_HYGROInitialize(t_experiment_data* expData);
static void Experiment_CLSInitialize(t_experiment_data* expData);
static void Experiment_7SDInitialize(t_experiment_data* expData);
static void Experiment_PeripheralsInitialize(t_experiment_data* expData);
static void Experiment_SetLedUpdate(t_experiment_data* expData,
		uint8_t silk, uint8_t red, uint8_t green, uint8_t blue);
static void Experiment_HYGROReadSensor(t_experiment_data* expData);
static void Experiment_UpdateCLSDisplay(t_experiment_data* expData);

/* Global variables */
t_experiment_data experiData; // Global as that the object is always in scope, including interrupt handler.

/*-----------------------------------------------------------*/
/* Helper function to initialize Experiment Data. */
static void Experiment_Initialize(t_experiment_data* expData)
{
	expData->switchesRead = 0x00000000;
	expData->buttonsRead = 0x00000000;
	expData->switchesReadPrev = 0x00000000;
	expData->buttonsReadPrev = 0x00000000;
}

/*-----------------------------------------------------------*/
/* Helper function to set an updated state to one of the 8 LEDs. */
static void Experiment_SetLedUpdate(t_experiment_data* expData,
		uint8_t silk, uint8_t red, uint8_t green, uint8_t blue)
{
	if (silk < 8) {
		expData->ledUpdate[silk].ledSilk = silk;
		expData->ledUpdate[silk].rgb.paletteRed = red;
		expData->ledUpdate[silk].rgb.paletteGreen = green;
		expData->ledUpdate[silk].rgb.paletteBlue = blue;
	}

	if (expData->ledUpdate[silk].ledSilk < 4) {
		SetRgbPaletteLed(expData->ledUpdate[silk].ledSilk, &(expData->ledUpdate[silk].rgb));
	} else if (expData->ledUpdate[silk].ledSilk < 8) {
		if (expData->ledUpdate[silk].rgb.paletteGreen <= 100) {
			SetBasicLedPercent(expData->ledUpdate[silk].ledSilk, 10 * expData->ledUpdate[silk].rgb.paletteGreen);
		}
	}
}

/*-----------------------------------------------------------*/
/* Helper function to initialize the discrete board LEDs. */
static void Experiment_LEDsInitialize(t_experiment_data* expData)
{
	InitAllLedsOff();
	for (int i = 0; i < 8; ++i)
		Experiment_SetLedUpdate(expData, i, 0, 0, 0);
}

/*-----------------------------------------------------------*/
/* Helper function to initialize the input GPIO connected to board Switches and Buttons. */
static void Experiment_UserIOInitialize(t_experiment_data* expData)
{
	XGpio_Initialize(&(expData->axGpio), USERIO_DEVICE_ID);
	XGpio_SelfTest(&(expData->axGpio));
	XGpio_SetDataDirection(&(expData->axGpio), SWTCH_SW_CHANNEL, SWTCHS_SWS_MASK);
	XGpio_SetDataDirection(&(expData->axGpio), BTNS_SW_CHANNEL, BTNS_SWS_MASK);
}

/*-----------------------------------------------------------*/
/* Helper function to initialize the Pmod HYGRO device. */
static void Experiment_HYGROInitialize(t_experiment_data* expData)
{
	HYGRO_begin(
		&(expData->hygroDevice),
		XPAR_PMODHYGRO_0_AXI_LITE_IIC_BASEADDR,
		0x40, // Chip address of PmodHYGRO IIC
		XPAR_PMODHYGRO_0_AXI_LITE_TMR_BASEADDR,
		XPAR_PMODHYGRO_0_DEVICE_ID,
		XPAR_CPU_M_AXI_DP_FREQ_HZ // Clock frequency of AXI bus, used to convert timer data
	);
}

/*-----------------------------------------------------------*/
/* Helper function to initialize the Pmod CLS device. */
static void Experiment_CLSInitialize(t_experiment_data* expData)
{
	CLS_begin(&(expData->clsDevice), XPAR_PMODCLS_0_AXI_LITE_SPI_BASEADDR);
	CLS_DisplayClear(&(expData->clsDevice));
}

/*-----------------------------------------------------------*/
/* Helper function to initialize the Pmod 7SD device. */
static void Experiment_7SDInitialize(t_experiment_data* expData)
{
	expData->ssdDigitRight = 0;
	expData->ssdDigitLeft = 0;
	MUXSSD_mWriteReg(XPAR_MUXSSD_0_S00_AXI_BASEADDR,
			MUXSSD_S00_AXI_SLV_REG0_OFFSET, expData->ssdDigitRight);
	MUXSSD_mWriteReg(XPAR_MUXSSD_0_S00_AXI_BASEADDR,
			MUXSSD_S00_AXI_SLV_REG1_OFFSET, expData->ssdDigitLeft);
}

/*-----------------------------------------------------------*/
/* Helper function to initialize each peripheral */
void Experiment_PeripheralsInitialize(t_experiment_data* expData)
{
	Experiment_HYGROInitialize(expData);
	Experiment_CLSInitialize(expData);
	Experiment_7SDInitialize(expData);
	Experiment_LEDsInitialize(expData);
	Experiment_UserIOInitialize(expData);
}

/*-----------------------------------------------------------*/
/* Helper function to read sensor values from the Pmod HYGRO peripheral */
static void Experiment_HYGROReadSensor(t_experiment_data* expData)
{
    expData->temp_degc = HYGRO_getTemperature(&(expData->hygroDevice));
    expData->temp_degf = HYGRO_tempC2F(expData->temp_degc);
    expData->hum_perrh = HYGRO_getHumidity(&(expData->hygroDevice));
}

/*-----------------------------------------------------------*/
/* Helper function to read sensor values from the Pmod HYGRO peripheral */
static void Experiment_UpdateCLSDisplay(t_experiment_data* expData)
{
	CLS_DisplayClear(&(expData->clsDevice));
    CLS_WriteStringAtPos(&(expData->clsDevice), 0, 0, expData->szInfo1);
    CLS_WriteStringAtPos(&(expData->clsDevice), 1, 0, expData->szInfo2);
}

/* Main routine */
/*-----------------------------------------------------------*/
int main()
{
    init_platform();

	Experiment_Initialize(&experiData);
	Experiment_PeripheralsInitialize(&experiData);

	for(;;)
	{

	}

    cleanup_platform();
    return 0;
}
