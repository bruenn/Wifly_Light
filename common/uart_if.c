/*
 Copyright (C) 2014 Nils Weiss, Patrick Bruenn.

 This file is part of WyLight.

 WyLight is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 WyLight is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with WyLight.  If not, see <http://www.gnu.org/licenses/>. */

//*****************************************************************************
// uart_if.c
//
// uart interface file: Prototypes and Macros for UARTLogger
//
// Copyright (C) 2014 Texas Instruments Incorporated - http://www.ti.com/ 
// 
// 
//  Redistribution and use in source and binary forms, with or without 
//  modification, are permitted provided that the following conditions 
//  are met:
//
//    Redistributions of source code must retain the above copyright 
//    notice, this list of conditions and the following disclaimer.
//
//    Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the 
//    documentation and/or other materials provided with the   
//    distribution.
//
//    Neither the name of Texas Instruments Incorporated nor the names of
//    its contributors may be used to endorse or promote products derived
//    from this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 
//  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
//  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
//  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT 
//  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
//  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT 
//  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
//  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE 
//  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//*****************************************************************************

#include <stdarg.h>
#include <stdlib.h>
#include <stdio.h>

#include "hw_types.h"
#include "hw_memmap.h"
#include "prcm.h"
#include "pin.h"
#include "uart.h"
#include "rom.h"
#include "rom_map.h"
#include "uart_if.h"

//*****************************************************************************
//
//! Initialization
//!
//! This function
//!		1. Configures the UART to be used.
//!
//! \return none
//
//*****************************************************************************
void 
InitTerm()
{
#ifndef NOTERM
  MAP_UARTConfigSetExpClk(CONSOLE,MAP_PRCMPeripheralClockGet(CONSOLE_PERIPH), 
                  UART_BAUD_RATE, (UART_CONFIG_WLEN_8 | UART_CONFIG_STOP_ONE |
                   UART_CONFIG_PAR_NONE));
#endif
}

//*****************************************************************************
//
//!	Outputs a character string to the console
//!
//! \param str is the pointer to the string to be printed
//!
//! This function
//!		1. prints the input string character by character on to the console.
//!
//! \return none
//
//*****************************************************************************
void 
Message(const char *str)
{
#ifndef NOTERM
    if(str != NULL)
    {
        while(*str)
        {
            MAP_UARTCharPut(CONSOLE,*str++);
        }
    }
#endif
}

//*****************************************************************************
//
//!	Clear the console window
//!
//! This function
//!		1. clears the console window.
//!
//! \return none
//
//*****************************************************************************
void 
ClearTerm()
{
	const char clearMsg[] = "\33[2J\r";
    Message(clearMsg);
}

//*****************************************************************************
//
//!	prints the formatted string on to the console
//!
//! \param format is a pointer to the character string specifying the format in
//!		   the following arguments need to be interpreted.
//! \param [variable number of] arguments according to the format in the first
//!         parameters
//! This function
//!		1. prints the formatted error statement.
//!
//! \return count of characters printed
//
//*****************************************************************************
int Report(const char *pcFormat, ...)
{
 int iRet = 0;
#ifndef NOTERM
  char pcBuff[256];
  int iSize = sizeof(pcBuff);
 
  va_list list;
  va_start(list,pcFormat);
  iRet = vsnprintf(pcBuff,iSize,pcFormat,list);
  va_end(list);

  if( iRet < 0 || iRet >= iSize) {
	  Message("Message to long\r\n");
	  return -1;
  }
  Message(pcBuff);
#endif
  return iRet;
}