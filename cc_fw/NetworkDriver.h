/*
 Copyright (C) 2014 Nils Weiss, Patrick Bruenn.
 
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
#ifndef __NETWORK_DRIVER__H__
#define __NETWORK_DRIVER__H__

#include <stdint.h>
#include <string>
#include "osi.h"
#include "FreeRTOS.h"
#include "semphr.h"

#include "simplelink.h"

class NetworkDriver {
    
    static const std::string GET_TOKEN;
    static const std::string POST_TOKEN;
    
    static const uint8_t SSID_LEN_MAX = 32;
    static const uint8_t BSSID_LEN_MAX = 6;
    static const uint8_t SEC_KEY_LEN_MAX = 64;
    static const uint8_t SL_STOP_TIMEOUT = 30;
    static const uint8_t MAX_NUM_NETWORKENTRIES = 10;
    static const uint16_t CONNECT_TIMEOUT = 20000;
    
    struct driverStatus {
        bool networkProcessorOn;
        bool connected;
        bool IPLeased;
        bool IPAcquired;
        bool connectFailed;
        bool pingDone;
        static void reset(struct driverStatus& status);
    };
    
    struct statusInformation {
        unsigned long SimpleLinkStatus;
        unsigned long StationIpAddress;
        unsigned long GatewayIpAddress;
        std::string ConnectionSSID;
        std::string ConnectionBSSID;
        unsigned short ConnectionTimeDelayIndex;
        static void reset(struct statusInformation& info);
    };
    
    struct provisioningData {
        unsigned char priority;
        std::string wlanSSID;
        std::string wlanSecurityKey;
        SlSecParams_t secParameters;
        Sl_WlanNetworkEntry_t networkEntries[MAX_NUM_NETWORKENTRIES];
        static void reset(struct provisioningData& data);
    };
    
    static struct driverStatus mStatus;
    static struct statusInformation mInfo;
    static struct provisioningData mProvisioningData;
    
    static xSemaphoreHandle mProvisioningDataSemaphore;
    
    static void responseNetworkEntries(const unsigned long entryNumber, SlHttpServerResponse_t *response);
    static long extractTokenNumber(SlHttpServerEvent_t const * const event);
    static char extractTokenParameter(SlHttpServerEvent_t const * const event);
    static void setSecurityKey(SlHttpServerEvent_t const * const event);
    static void setSecurityType(SlHttpServerEvent_t const * const event);
    
    static long waitForConnectWithTimeout(const unsigned int timeout_ms);
    static long configureSimpleLinkToDefaultState(void);
    static long startAsStation(void);
    static long startAsAccesspoint(void);
    static void disconnect(void);
    static long addNewProfile(void);

public:
    static NetworkDriver* g_Instance;

    
    NetworkDriver(const bool accesspointMode);
    NetworkDriver(const NetworkDriver&) = delete;
    NetworkDriver& operator=(const NetworkDriver&) = delete;
    NetworkDriver(NetworkDriver&&) = delete;
    ~NetworkDriver(void);
    
    void waitForNewProvisioningData(void) const;
    operator bool() const;
    bool isConnected(void) const;

    
    static void SimpleLinkWlanEventHandler(SlWlanEvent_t *pSlWlanEvent);
    static void SimpleLinkNetAppEventHandler(SlNetAppEvent_t *pNetAppEvent);
    static void SimpleLinkGeneralEventHandler(SlDeviceEvent_t *pDevEvent);
    static void SimpleLinkSockEventHandler(SlSockEvent_t *pSock);
    static void SimpleLinkHttpServerCallback(SlHttpServerEvent_t *pSlHttpServerEvent, SlHttpServerResponse_t *pSlHttpServerResponse);
};

#endif
