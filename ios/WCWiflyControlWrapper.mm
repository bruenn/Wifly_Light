//
//  WCWiflyControlWrapper.m
//
//  Created by Bastian Kres on 16.04.13.
//  Copyright (c) 2013 Bastian Kres, Nils Weiß. All rights reserved.
//

#import "WCWiflyControlWrapper.h"
#import "WCEndpoint.h"
#include "WiflyControl.h"
#include "FirmwareControl.h"
#include "ConfigControl.h"
#include "BootloaderControl.h"
#include "StartupManager.h"
#include <thread>
#include <mutex>
#include <functional>
#include "MessageQueue.h"
#include <tuple>
#include <list>

typedef std::function<uint32_t(void)> ControlCommand;

//tupel <1> == true: terminate task; tuple <2>: command to execute; tuple<3> == 0: no notification after execution command, == 1: connection lost after execution command
typedef std::tuple<bool, ControlCommand, unsigned int> ControlMessage;

@interface WCWiflyControlWrapper () {
	std::shared_ptr<WyLight::Control> mControl;
	std::shared_ptr<std::thread> mCtrlThread;
	std::shared_ptr<std::mutex> gCtrlMutex;
	std::shared_ptr < WyLight::MessageQueue < ControlMessage >> mCmdQueue;
}

@property (nonatomic, strong) WCEndpoint *endpoint;
@property (atomic, readwrite) bool appOutdated;
@property (atomic, readwrite) bool clientWithWS2801Leds;


-(void) callFatalErrorDelegate:(NSNumber *)errorCode;
-(void) callWiflyControlHasDisconnectedDelegate;
-(void) startupManagerStateChanged:(NSNumber *)state;

@end

@implementation WCWiflyControlWrapper

#pragma mark - Object

- (id)init
{
	@throw ([NSException exceptionWithName:@"Wrong init-method" reason:@"Use -initWithEndpoint:establishConnection:" userInfo:nil]);
}

- (id)initWithWCEndpoint:(WCEndpoint *)endpoint establishConnection:(BOOL)connect doStartup:(BOOL)doStartup
{
	self = [super init];
	if(self) {
		self.appOutdated = NO;
		self.clientWithWS2801Leds = NO;
		self.endpoint = endpoint;
		if(connect) {
			if([self connectWithStartup:doStartup] != 0) {
				return nil;
			}
		}
	}
	return self;
}

- (int)connectWithStartup:(BOOL)doStartup
{
	gCtrlMutex = std::make_shared<std::mutex>();
	try {
						NSLog(@"Start WCWiflyControlWrapper\n");
		std::lock_guard<std::mutex> ctrlLock(*gCtrlMutex);
		
		const WyLight::Endpoint endpoint(self.endpoint.ipAdress,
										 self.endpoint.port,
										 self.endpoint.score,
										 [self.endpoint.name cStringUsingEncoding:NSASCIIStringEncoding],
										 (WyLight::Endpoint::TYPE)self.endpoint.type);
		
		if (endpoint.GetType() == WyLight::Endpoint::RN171){
			mControl = std::shared_ptr<WyLight::Control>(new WyLight::RN171Control(endpoint));
		} else if (endpoint.GetType() == WyLight::Endpoint::CC3200){
			mControl = std::shared_ptr<WyLight::Control>(new WyLight::CC3200Control(endpoint));
		} else {
			return -1;
		}
	} catch(std::exception &e) {
		NSLog(@"%s", e.what());
		return -1;
	}

	if(doStartup) {
		try {
			[[UIApplication sharedApplication] setIdleTimerDisabled:YES];

			WyLight::StartupManager starter([&](size_t newState){
					[self startupManagerStateChanged:@(newState)];
				}
				);

			NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"main" ofType:@"hex"];
			const std::string hexFileString = std::string([filePath cStringUsingEncoding:NSASCIIStringEncoding]);

			starter.startup(*mControl, hexFileString);

			[[UIApplication sharedApplication] setIdleTimerDisabled:NO];

			if(starter.getCurrentState() != WyLight::StartupManager::STARTUP_SUCCESSFUL) {
				return -1;
			}
			self.appOutdated = starter.isAppOutdated();

		} catch(std::exception &e) {
						NSLog(@"%s", e.what());
			[[UIApplication sharedApplication] setIdleTimerDisabled:NO];
			return -1;
		}
	}
	try {
		if ((mControl->mFirmware) && (mControl->mFirmware->FwGetLedTyp() == LED_TYP_WS2801)) {
			self.clientWithWS2801Leds = YES;
		} else {
			self.clientWithWS2801Leds = NO;
		}
	
	} catch(std::exception &e) {
		NSLog(@"%s", e.what());
		return -1;
	}
	
	//FIX complex script view is never called
	self.clientWithWS2801Leds = NO;

	mCmdQueue = std::make_shared < WyLight::MessageQueue < ControlMessage >> ();
	mCmdQueue->setMessageLimit(70);
	mCtrlThread = std::make_shared<std::thread>
			([ = ] {
				while(true)
				{
					auto tup = mCmdQueue->receive();

					if(std::get<0>(tup)) {
						NSLog(@"WCWiflyControlWrapper: Terminate runLoop\n");
						break;
					}
					
					try {
						std::lock_guard<std::mutex> ctrlLock(*gCtrlMutex);
						dispatch_async(dispatch_get_main_queue(), ^{
							[self setNetworkActivityIndicatorVisible:YES];
						});
						
						if(mControl) {
							std::get<1>(tup)();
						}
						
						double delayInSeconds = 0.3;
						dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
						dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
							[self setNetworkActivityIndicatorVisible:NO];
						});
						
						if(std::get<2>(tup) == 1)   { //do we have to notify after execution?
							[self callWiflyControlHasDisconnectedDelegate];
						}
						
					}catch (WyLight::ScriptBufferFull &e){
						NSLog(@"%s", e.what());
						dispatch_async(dispatch_get_main_queue(), ^{
							[self setNetworkActivityIndicatorVisible:NO];
						});
						[self callFatalErrorDelegate:@(WyLight::SCRIPT_FULL)];
					}
					catch (std::exception &e) {
						NSLog(@"%s", e.what());
						dispatch_async(dispatch_get_main_queue(), ^{
							[self setNetworkActivityIndicatorVisible:NO];
						});
						[self callFatalErrorDelegate:@(WyLight::FATAL_ERROR)];
					}
				}
			}
			);

	[[NSNotificationCenter defaultCenter] addObserver: self
	 selector: @selector(handleEnteredBackground:)
	 name: UIApplicationDidEnterBackgroundNotification
	 object: nil];
	
	return 0;
}

- (void)disconnect
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self callWiflyControlHasDisconnectedDelegate];

	dispatch_async(dispatch_queue_create("disconnectQ", NULL), ^{
			       if(mCmdQueue && mCtrlThread) {
				       NSLog(@"Disconnect WCWiflyControlWrapper\n");
				       mCmdQueue->clear_and_push_front(std::make_tuple(true, [ = ] {return 0xdeadbeef; }, 0));
				       mCtrlThread->join();

			       }

			       mCtrlThread.reset();
			       mCmdQueue.reset();
			       gCtrlMutex.reset();
			       mControl.reset();
		       }
		       );
}

- (void)handleEnteredBackground:(NSNotification *)notification {
	if([notification.name isEqualToString:UIApplicationDidEnterBackgroundNotification]) {
		[self disconnect];
	}
}

- (void)setNetworkActivityIndicatorVisible:(BOOL)setVisible {
	static NSInteger NumberOfCallsToSetVisible = 0;
	if(setVisible)
		NumberOfCallsToSetVisible++;
	else
		NumberOfCallsToSetVisible--;

	// The assertion helps to find programmer errors in activity indicator management.
	// Since a negative NumberOfCallsToSetVisible is not a fatal error,
	// it should probably be removed from production code.
	NSAssert(NumberOfCallsToSetVisible >= 0, @"Network Activity Indicator was asked to hide more often than shown");

	// Display the indicator as long as our static counter is > 0.
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:(NumberOfCallsToSetVisible > 0)];
}

#pragma mark - Configuration WLAN-Module

- (void)configurateWlanModuleAsClientForNetwork:(NSString *)ssid password:(NSString *)password name:(NSString *)name
{
	if (!mControl->mConfig) {
		return;
	}
	NSData *nameData = [name dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
	NSString *nameStr = [[NSString alloc] initWithData:nameData encoding:NSASCIIStringEncoding];

	const std::string ssidCString([ssid cStringUsingEncoding:NSASCIIStringEncoding]);
	const std::string passwordCString([password cStringUsingEncoding:NSASCIIStringEncoding]);
	const std::string nameCString([nameStr cStringUsingEncoding:NSASCIIStringEncoding]);
	
	mCmdQueue->push_back(std::make_tuple(false,
										 std::bind(&WyLight::ConfigControl::ModuleForWlan, std::ref(mControl->mConfig), passwordCString, ssidCString, nameCString),
					     1));
}

- (void)configurateWlanModuleAsSoftAP:(NSString *)ssid
{
	if (!mControl->mConfig) {
		return;
	}
	const std::string ssidCString([ssid cStringUsingEncoding:NSASCIIStringEncoding]);

	mCmdQueue->push_back(std::make_tuple(false,
										 std::bind(&WyLight::ConfigControl::ModuleAsSoftAP, std::ref(mControl->mConfig), ssidCString),
					     1));
}

- (void)rebootWlanModul
{
	if (!mControl->mConfig) {
		return;
	}
	mCmdQueue->push_back(std::make_tuple(false,
										 std::bind(&WyLight::ConfigControl::RebootWlanModule, std::ref(mControl->mConfig)),
					     1));
}

#pragma mark - Firmware methods

- (void)setColorDirectWithColors:(NSArray *)newColors
{
	CGFloat redPart;
	CGFloat greenPart;
	CGFloat bluePart;
	CGFloat alphaPart;


	size_t sizeColorArray = MIN(NUM_OF_LED, newColors.count);

	uint8_t colorArray[NUM_OF_LED * 3];
	uint8_t *pointer = colorArray;

	for(int i = 0; i < NUM_OF_LED; i++) {
		redPart = 0;
		greenPart = 0;
		bluePart = 0;
		alphaPart = 0;

		if(newColors[i]) {
			[newColors[i] getRed:&redPart green:&greenPart blue:&bluePart alpha:&alphaPart];
		} else {
			[[UIColor blackColor] getRed:&redPart green:&greenPart blue:&bluePart alpha:&alphaPart];
		}

		*pointer++ = (uint8_t)(redPart * alphaPart * 255);
		*pointer++ = (uint8_t)(greenPart * alphaPart * 255);
		*pointer++ = (uint8_t)(bluePart * alphaPart * 255);
	}

	[self setColorDirect:colorArray bufferLength:sizeColorArray * 3];
}

- (void)setColorDirect:(UIColor *)newColor
{
	CGFloat redPart;
	CGFloat greenPart;
	CGFloat bluePart;
	[newColor getRed:&redPart green:&greenPart blue:&bluePart alpha:nil];

	const size_t sizeColorArray = NUM_OF_LED * 3;

	uint8_t colorArray[sizeColorArray];
	uint8_t *pointer = colorArray;

	for(int i = 0; i < sizeColorArray; i++) {
		switch(i % 3)
		{
		case 2:
			*pointer++ = (uint8_t)(bluePart * 255);
			break;
		case 1:
			*pointer++ = (uint8_t)(greenPart * 255);
			break;
		case 0:
			*pointer++ = (uint8_t)(redPart * 255);
			break;
		}
	}

	[self setColorDirect:colorArray bufferLength:sizeColorArray];
}

- (void)setColorDirect:(const uint8_t *)pointerBuffer bufferLength:(size_t)length
{
	if (!mControl->mFirmware) {
		return;
	}
	std::vector<uint8_t> buffer(pointerBuffer, pointerBuffer + length);
	mCmdQueue->push_back(std::make_tuple(false,
										 [=](void) -> unsigned int {*mControl->mFirmware << WyLight::FwCmdSetColorDirect(buffer.data(), buffer.size());return 0;},
					     0));
}

- (void)setWaitTimeInTenMilliSecondsIntervals:(uint16_t)time
{
	if (!mControl->mFirmware) {
		return;
	}
	mCmdQueue->push_back(std::make_tuple(false,
					     [=](void) -> unsigned int {*mControl->mFirmware << WyLight::FwCmdWait(time);return 0;},
					     0));
}

- (void)setFade:(uint32_t)colorInARGB
{
	[self setFade:colorInARGB time:0];
}

- (void)setFade:(uint32_t)colorInARGB time:(uint16_t)timeValue
{
	[self setFade:colorInARGB time:timeValue address:0xffffffff];
}

- (void)setFade:(uint32_t)colorInARGB time:(uint16_t)timeValue address:(uint32_t)address
{
	[self setFade:colorInARGB time:timeValue address:address parallelFade:false];
}

- (void)setFade:(uint32_t)colorInARGB time:(uint16_t)timeValue address:(uint32_t)address parallelFade:(BOOL)parallel
{
	if (!mControl->mFirmware) {
		return;
	}
	mCmdQueue->push_back(std::make_tuple(false,
						 [=](void) -> unsigned int {*mControl->mFirmware << WyLight::FwCmdSetFade(colorInARGB, timeValue, address, parallel);return 0;},
					     0));
}

- (void)setGradientWithColor:(uint32_t)colorOneInARGB colorTwo:(uint32_t)colorTwoInARGB
{
	[self setGradientWithColor:colorOneInARGB colorTwo:colorTwoInARGB time:0];
}

- (void)setGradientWithColor:(uint32_t)colorOneInARGB colorTwo:(uint32_t)colorTwoInARGB time:(uint16_t)timeValue
{
	[self setGradientWithColor:colorOneInARGB colorTwo:colorTwoInARGB time:timeValue parallelFade:false];
}

- (void)setGradientWithColor:(uint32_t)colorOneInARGB colorTwo:(uint32_t)colorTwoInARGB time:(uint16_t)timeValue parallelFade:(BOOL)parallel
{
	[self setGradientWithColor:colorOneInARGB colorTwo:colorTwoInARGB time:timeValue parallelFade:parallel gradientLength:NUM_OF_LED];
}

- (void)setGradientWithColor:(uint32_t)colorOneInARGB colorTwo:(uint32_t)colorTwoInARGB time:(uint16_t)timeValue parallelFade:(BOOL)parallel gradientLength:(uint8_t)length
{
	[self setGradientWithColor:colorOneInARGB colorTwo:colorTwoInARGB time:timeValue parallelFade:parallel gradientLength:length startPosition:0];
}

- (void)setGradientWithColor:(uint32_t)colorOneInARGB colorTwo:(uint32_t)colorTwoInARGB time:(uint16_t)timeValue parallelFade:(BOOL)parallel gradientLength:(uint8_t)length startPosition:(uint8_t)offset
{
	if (!mControl->mFirmware) {
		return;
	}
	mCmdQueue->push_back(std::make_tuple(false,
						[=](void) -> unsigned int {*mControl->mFirmware << WyLight::FwCmdSetGradient(colorOneInARGB, colorTwoInARGB, timeValue, parallel, length, offset);return 0;},
					     0));
}

- (void)loopOn
{
	if (!mControl->mFirmware) {
		return;
	}
	mCmdQueue->push_back(std::make_tuple(false,
[=](void) -> unsigned int {*mControl->mFirmware << WyLight::FwCmdLoopOn();return 0;},
										 0));
}

- (void)loopOffAfterNumberOfRepeats:(uint8_t)repeats
{
	if (!mControl->mFirmware) {
		return;
	}
	mCmdQueue->push_back(std::make_tuple(false,
					    [=](void) -> unsigned int {*mControl->mFirmware << WyLight::FwCmdLoopOff(repeats);return 0;},
					     0));                            // 0: Endlosschleife / 255: Maximale Anzahl
}

- (void)clearScript
{
	if (!mControl->mFirmware) {
		return;
	}
	mCmdQueue->push_back(std::make_tuple(false,
					     [=](void) -> unsigned int {*mControl->mFirmware << WyLight::FwCmdClearScript();return 0;},
					     0));
}

- (NSDate *)readRtcTime
{
	if(mControl && mControl->mFirmware) {
		try {
			struct tm timeInfo;
			std::lock_guard<std::mutex> lock(*gCtrlMutex);
			
			mControl->mFirmware->FwGetRtc(timeInfo);
			return [NSDate dateWithTimeIntervalSince1970:mktime(&timeInfo)];

		} catch (std::exception &e) {
			NSLog(@"%s", e.what());
			[self callFatalErrorDelegate:[NSNumber numberWithUnsignedInt:WyLight::FATAL_ERROR]];
		}

	}
	return nil;
}

- (void)writeRtcTime
{
	if (!mControl->mFirmware) {
		return;
	}
	NSTimeInterval timeInterval = [[NSDate date] timeIntervalSince1970];
	struct tm *timeInfo;
	time_t rawTime = (time_t)timeInterval;

	timeInfo = localtime(&rawTime);

	mCmdQueue->push_front(std::make_tuple(false,
										  [=](void) -> unsigned int {*mControl->mFirmware << WyLight::FwCmdSetRtc(*timeInfo);return 0;},
					      0));
}

- (void)callFatalErrorDelegate:(NSNumber *)errorCode
{
	dispatch_async(dispatch_get_main_queue(), ^{
			       NSLog(@"ErrorCode %@", errorCode);
			       if([errorCode intValue] == WyLight::SCRIPT_FULL) {
				       [self.delegate wiflyControl:self scriptBufferErrorOccured:errorCode];
			       } else {
				       [self.delegate wiflyControl:self fatalErrorOccured:errorCode];
			       }
		       }
		       );
}

- (void)callWiflyControlHasDisconnectedDelegate
{
	dispatch_async(dispatch_get_main_queue(), ^{
			       NSLog(@"%@", self.delegate);
			       [self.delegate wiflyControlHasDisconnected:self];
		       }
		       );
}

- (void)startupManagerStateChanged:(NSNumber *)state
{
	dispatch_async(dispatch_get_main_queue(), ^{
			       NSLog(@"StartupManager state changed to:%lu", (unsigned long)state.unsignedIntegerValue);
			       [self.delegate wiflyControl:self connectionStartupStateChanged:state];
		       }
		       );
}

@end
