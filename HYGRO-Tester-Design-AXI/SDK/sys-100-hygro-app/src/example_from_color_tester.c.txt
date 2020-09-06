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
 * @file color_tester_main.c
 *
 * @brief A SoPC top-level design with color mixing and text display logic.
 * This design operates the Pmod KYPD to input an 11-digit code to then process
 * and output a color value to one discrete RGB LED, and text of that color to
 * the Pmod OLEDrgb peripheral.
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

#include <stdlib.h>
#include <stdio.h>
#include "sleep.h"
#include "platform.h"
#include "xil_printf.h"
#include "xgpio.h"
#include "PmodOLEDrgb.h"
#include "PmodKYPD.h"
#include "led_pwm.h"

/* Global constants */
// keytable is determined as follows (indices shown in Keypad position below)
// 12 13 14 15
// 8  9  10 11
// 4  5  6  7
// 0  1  2  3
#define DEFAULT_KEYTABLE "0FED789C456B123A"

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
	PmodOLEDrgb oledrgbDevice;
	PmodKYPD kypdDevice;
	/* LED driver palettes stored */
	t_rgb_led_palette_silk ledUpdate[8];
	/* GPIO reading values at this point in the execution */
	u32 switchesRead;
	u32 buttonsRead;
	u32 switchesReadPrev;
	u32 buttonsReadPrev;
	/* Captured keypad string */
	XStatus kypdStatus;
	XStatus kypdLastStatus;
	u8 key;
	u8 lastKey;
	u8 stringIdx;
	u8 capturedString[CAPTURED_STRING_LENGTH];
} t_experiment_data;

/* Function prototypes */
static void Experiment_OLEDInitialize(t_experiment_data* expData);
static void Experiment_KYPDInitialize(t_experiment_data* expData);
static void Experiment_LEDsInitialize(t_experiment_data* expData);
static void Experiment_UserIOInitialize(t_experiment_data* expData);
static void Experiment_PeripheralsInitialize(t_experiment_data* expData);
static void Experiment_SetLedUpdate(t_experiment_data* expData,
		uint8_t silk, uint8_t red, uint8_t green, uint8_t blue);

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
	expData->kypdStatus = KYPD_NO_KEY;
	expData->kypdLastStatus = KYPD_NO_KEY;
	expData->key = 'x';
	expData->lastKey = 'x';
	expData->stringIdx = 0;
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
/* Helper function to initialize the OLEDrgb peripheral. */
void Experiment_OLEDInitialize(t_experiment_data* expData)
{
	OLEDrgb_begin(&(expData->oledrgbDevice), XPAR_PMODOLEDRGB_0_AXI_LITE_GPIO_BASEADDR,
			XPAR_PMODOLEDRGB_0_AXI_LITE_SPI_BASEADDR);

	OLEDrgb_SetCursor(&(expData->oledrgbDevice), 0, 0);
	OLEDrgb_SetFontColor(&(expData->oledrgbDevice), OLEDrgb_BuildRGB(255, 255, 255)); // White font
	OLEDrgb_PutString(&(expData->oledrgbDevice), "Colors Test:");
	OLEDrgb_SetCursor(&(expData->oledrgbDevice), 0, 1);
	OLEDrgb_SetFontColor(&(expData->oledrgbDevice), OLEDrgb_BuildRGB(255, 255, 255)); // White font
	OLEDrgb_PutString(&(expData->oledrgbDevice), "for  compare");
	OLEDrgb_SetCursor(&(expData->oledrgbDevice), 0, 2);
	OLEDrgb_SetFontColor(&(expData->oledrgbDevice), OLEDrgb_BuildRGB(255, 255, 255)); // White font
	OLEDrgb_PutString(&(expData->oledrgbDevice), "  RGB   LEDs");
	OLEDrgb_SetCursor(&(expData->oledrgbDevice), 0, 3);
	OLEDrgb_SetFontColor(&(expData->oledrgbDevice), OLEDrgb_BuildRGB(255, 255, 255)); // White font
	OLEDrgb_PutString(&(expData->oledrgbDevice), "and OLEDrgb.");
}

/*-----------------------------------------------------------*/
/* Helper function to initialize the KYPD peripheral. */
void Experiment_KYPDInitialize(t_experiment_data* expData)
{
	KYPD_begin(&(expData->kypdDevice), XPAR_PMODKYPD_0_AXI_LITE_GPIO_BASEADDR);
	KYPD_loadKeyTable(&(expData->kypdDevice), (u8*) DEFAULT_KEYTABLE);
}

/*-----------------------------------------------------------*/
/* Helper function to initialize the discrete board LEDs. */
void Experiment_LEDsInitialize(t_experiment_data* expData)
{
	InitAllLedsOff();
	for (int i = 0; i < 8; ++i)
		Experiment_SetLedUpdate(expData, i, 0, 0, 0);
}

/*-----------------------------------------------------------*/
/* Helper function to initialize the input GPIO connected to board Switches and Buttons. */
void Experiment_UserIOInitialize(t_experiment_data* expData)
{
	XGpio_Initialize(&(expData->axGpio), USERIO_DEVICE_ID);
	XGpio_SelfTest(&(expData->axGpio));
	XGpio_SetDataDirection(&(expData->axGpio), SWTCH_SW_CHANNEL, SWTCHS_SWS_MASK);
	XGpio_SetDataDirection(&(expData->axGpio), BTNS_SW_CHANNEL, BTNS_SWS_MASK);
}

/*-----------------------------------------------------------*/
/* Helper function to initialize each peripheral */
void Experiment_PeripheralsInitialize(t_experiment_data* expData)
{
	Experiment_OLEDInitialize(expData);
	Experiment_KYPDInitialize(expData);
	Experiment_LEDsInitialize(expData);
	Experiment_UserIOInitialize(expData);
}

/*-----------------------------------------------------------*/
/* Helper function to capture user input on keypad */
void Experiment_CaptureStringFromKeypad(t_experiment_data* expData)
{
	u16 keystate;

	Xil_Out32(expData->kypdDevice.GPIO_addr, 0xF);

	for(;;)
	{
		// Capture the state of each key
		keystate = KYPD_getKeyStates(&(expData->kypdDevice));

		// Determine which single key is pressed, if any
		expData->kypdStatus = KYPD_getKeyPressed(&(expData->kypdDevice), keystate, &(expData->key));

		// Capture new key if a new key is pressed or if status has changed
		if ((expData->kypdStatus == KYPD_SINGLE_KEY) &&
				((expData->kypdStatus != expData->kypdLastStatus) || (expData->key != expData->lastKey)))
		{
			xil_printf("Key Pressed: %c\r\n", (char)(expData->key));
			expData->lastKey = expData->key;

			// All sequences to capture start with key press 'A'
			if (expData->key == 'A')
			{
				expData->stringIdx = 0;
			}

			if (expData->stringIdx < CAPTURED_STRING_LENGTH)
			{
				expData->capturedString[expData->stringIdx] = expData->key;
				++(expData->stringIdx);
			}

			// All sequences to capture are length \ref CAPTURED_STRING_LENGTH
			if (expData->stringIdx == CAPTURED_STRING_LENGTH)
			{
				expData->kypdLastStatus = expData->kypdStatus;
				expData->stringIdx = 0;
				break;
			}
		}
		else if ((expData->kypdStatus == KYPD_MULTI_KEY) && (expData->kypdStatus != expData->kypdLastStatus))
		{
			xil_printf("Error: Multiple keys pressed\r\n");
		}

		expData->kypdLastStatus = expData->kypdStatus;

		usleep(1000);
	}
}

/*-----------------------------------------------------------*/
/* Main routine to perform color mixing. */
int main()
{
	const u8 INVALID_LED_SILK = 255;
	char ledChanValue[4] = {'0', '0', '0', '\0'};
	u8 rgbChanValues[3];
	u8 ledSilkIdx;
	char printBuf[16];
	init_platform();

	Experiment_Initialize(&experiData);
	Experiment_PeripheralsInitialize(&experiData);

	for(;;)
	{
		Experiment_CaptureStringFromKeypad(&experiData);

		usleep(500000); /* Delay for human factors */

		if (experiData.capturedString[0] == 'A')
		{
			switch (experiData.capturedString[1])
			{
			case '0': ledSilkIdx = 0; break;
			case '1': ledSilkIdx = 1; break;
			case '2': ledSilkIdx = 2; break;
			case '3': ledSilkIdx = 3; break;
			default: ledSilkIdx = INVALID_LED_SILK; break;
			}

			if (ledSilkIdx != INVALID_LED_SILK)
			{
				ledChanValue[0] = experiData.capturedString[2];
				ledChanValue[1] = experiData.capturedString[3];
				ledChanValue[2] = experiData.capturedString[4];
				rgbChanValues[0] = atoi(ledChanValue);

				ledChanValue[0] = experiData.capturedString[5];
				ledChanValue[1] = experiData.capturedString[6];
				ledChanValue[2] = experiData.capturedString[7];
				rgbChanValues[1] = atoi(ledChanValue);

				ledChanValue[0] = experiData.capturedString[8];
				ledChanValue[1] = experiData.capturedString[9];
				ledChanValue[2] = experiData.capturedString[10];
				rgbChanValues[2] = atoi(ledChanValue);

				xil_printf("Testing RGB mix LED%u: %03u,%03u,%03u = 0x%02x%02x%02x\r\n",
						ledSilkIdx,
						rgbChanValues[0], rgbChanValues[1], rgbChanValues[2],
						rgbChanValues[0], rgbChanValues[1], rgbChanValues[2]);

				Experiment_SetLedUpdate(&experiData, ledSilkIdx,
						rgbChanValues[0],
						rgbChanValues[1],
						rgbChanValues[2]);

				OLEDrgb_SetCursor(&(experiData.oledrgbDevice),
						0, 4+ledSilkIdx);
				OLEDrgb_SetFontColor(&(experiData.oledrgbDevice),
						OLEDrgb_BuildRGB( /* The driver has a bug where RGB is actually BRG */
								rgbChanValues[0],
								rgbChanValues[1],
								rgbChanValues[2]));
				snprintf(printBuf, sizeof(printBuf),
						"Color LED%d  ", ledSilkIdx);
				OLEDrgb_PutString(&(experiData.oledrgbDevice), printBuf);
			}
		}
	}

	cleanup_platform();
	return 0;
}
