//
//  NWColorPickerViewController.m
//  WyLightRemote
//
//  Created by Nils Weiß on 07.08.13.
//  Copyright (c) 2013 Nils Weiß. All rights reserved.
//

#import "NWColorPickerViewController.h"
#import "KZColorPicker.h"
#import "WCWiflyControlWrapper.h"

@interface NWColorPickerViewController ()

@property (nonatomic) BOOL sendAnyCommandToControlHandle;

@end

@implementation NWColorPickerViewController

- (void)defaultColorController:(NWDefaultColorPickerViewController *)controller didChangeColor:(UIColor *)color {
	if (self.controlHandle) {
		if (!self.sendAnyCommandToControlHandle) {
			[self.controlHandle clearScript];
			self.sendAnyCommandToControlHandle = YES;
		}
		[self.controlHandle setColorDirect:color];
	}
}

//#define SELECTED_COLOR_KEY @"WyLightRemote.NWColorPicerViewController.selectedColor"
#define SELECTED_COLOR_KEY CURRENT_COLOR_KEY

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	self.sendAnyCommandToControlHandle = NO;
	[self deserializeColor];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	[self setColorPickerDelegate:self];
	
}

- (void)deserializeColor {
	NSData *colorData = [[NSUserDefaults standardUserDefaults] objectForKey:SELECTED_COLOR_KEY];
	if (colorData) {
		self.selectedColor = [NSKeyedUnarchiver unarchiveObjectWithData:colorData];
		[self setColorPickerSelectedColor:self.selectedColor];
	} else {
		UIColor *defaultColor = [UIColor colorWithRed:0.01 green:0.01 blue:0.01 alpha:1];
		self.selectedColor = defaultColor;
		[self setColorPickerSelectedColor:defaultColor];
	}
}

- (void)viewWillDisappear:(BOOL)animated {
	NSData *colorData = [NSKeyedArchiver archivedDataWithRootObject:self.selectedColor];
	[[NSUserDefaults standardUserDefaults] setObject:colorData forKey:SELECTED_COLOR_KEY];
	[super viewWillDisappear:animated];
}

@end

