/*
 Copyright (C) 2013 - 2015 Nils Weiss, Patrick Bruenn.

 This file is part of Wifly_Light.

 Wifly_Light is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Wifly_Light is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Wifly_Light.  If not, see <http://www.gnu.org/licenses/>. */

#ifndef _BROADCAST_MESSAGE_H_
#define _BROADCAST_MESSAGE_H_

#include <stdint.h>
#include <string>

namespace WyLight {

#pragma pack(push)
#pragma pack(1)
	struct BroadcastMessage
	{
		uint8_t mac[6];
		uint8_t channel;
		uint8_t rssi;
		uint16_t port;
		uint32_t rtc;
		uint16_t bat_mV;
		uint16_t gpioValue;
		int8_t asciiTime[13 + 1];
		int8_t version[26 + 1 + 1]; // this seems a little strange. bug in wifly fw?
		int8_t deviceId[32];
		uint16_t bootTmms;
		uint16_t sensor[8];
        
        bool IsVersion(const std::string& deviceVersion) const;
        bool IsDevice(const std::string& deviceType) const;
    };
#pragma pack(pop)
    
    struct RN171BroadcastMessage : public BroadcastMessage
    {
        static bool IsRN171Broadcast(const BroadcastMessage& msg, const size_t length);
        
        static const std::string DEVICE_ID;
        static const std::string DEVICE_ID_OLD;
        static const std::string DEVICE_VERSION;
        static const std::string DEVICE_VERSION4;
    };
    
    struct CC3200BroadcastMessage : public BroadcastMessage {
        void refresh(void);
        
        static bool IsCC3200Broadcast(const BroadcastMessage& msg, const size_t length);
        static const std::string DEVICE_VERSION;
    };
}
#endif /* #ifndef _BROADCAST_MESSAGE_H_ */
