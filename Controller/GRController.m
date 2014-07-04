// GRController.m
// Created by Rob Rix on 2009-05-25
// Copyright 2009 Rob Rix

#import "GRAreaSelectionView.h"
#import "GRController.h"
#import "GRPreferencesController.h"
#import "GRWindowController.h"
#import <Carbon/Carbon.h>
#import <Haxcessibility/Haxcessibility.h>
#import <ShortcutRecorder/ShortcutRecorder.h>

@interface GRController () <GRWindowControllerDelegate, NSApplicationDelegate>

@property (nonatomic, strong) HAXWindow *windowElement;
@property (nonatomic, strong) HAXApplication *focusedApplication;

-(void)shortcutKeyWasPressed:(NSNotification *)notification;

-(void)activate;
-(void)deactivate;

@property (nonatomic, assign) NSUInteger activeControllerIndex;

@property (nonatomic, copy) NSArray *controllers;

@end

@implementation GRController

-(void)awakeFromNib {
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(shortcutKeyWasPressed:) name:GRShortcutWasPressedNotification object:nil];
}

-(void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:GRShortcutWasPressedNotification object:nil];
}


-(NSUInteger)indexOfWindowControllerForWindowElementWithFrame:(CGRect)frame {
	CGPoint topLeft = CGPointMake(CGRectGetMinX(frame), CGRectGetMinY(frame));
	NSUInteger result = 0;
	NSUInteger index = 0;
	for (GRWindowController *controller in self.controllers) {
		if(CGRectContainsPoint(controller.screen.frame, topLeft)) {
			result = index;
			break;
		}
		index++;
	}
	return result;
}


-(void)shortcutKeyWasPressed:(NSNotification *)notification {
	if (self.windowElement) {
		[self deactivate];
	} else {
		self.focusedApplication = [HAXSystem system].focusedApplication;
		if ((self.windowElement = self.focusedApplication.focusedWindow)) {
			CGRect frame = self.windowElement.frame;
			[self activate];
			self.activeControllerIndex = [self indexOfWindowControllerForWindowElementWithFrame:frame];
		} else {
			[self deactivate];
		}
	}
}


-(void)activate {
	NSMutableArray *controllers = [NSMutableArray array];
	for (NSScreen *screen in [NSScreen screens]) {
		GRWindowController *controller = [GRWindowController controllerWithScreen:screen];
		controller.delegate = self;
		[controllers addObject:controller];
	}
	self.controllers = controllers;
	
	[self.controllers makeObjectsPerformSelector:@selector(activate)];
}

-(void)deactivate {
	[self.controllers makeObjectsPerformSelector:@selector(deactivate)];
	self.controllers = nil;
	self.windowElement = nil;
	
	if ([NSApplication sharedApplication].isActive)
		[[NSRunningApplication runningApplicationWithProcessIdentifier:self.focusedApplication.processIdentifier] activateWithOptions:0];
	
	self.focusedApplication = nil;
}


-(void)setActiveControllerIndex:(NSUInteger)index {
	_activeControllerIndex = index;
	[[self.controllers objectAtIndex:self.activeControllerIndex] showWindow:nil]; // focus on the active screen (by default, the one the window is on; can be switched with ⌘` and ⇧⌘`)
}


-(void)applicationDidResignActive:(NSNotification *)notification {
	[self deactivate];
}


-(void)windowController:(GRWindowController *)controller didSelectArea:(CGRect)selectedArea {
	CGPoint screenOffset = controller.screen.frame.origin;
	selectedArea = CGRectOffset(selectedArea, -screenOffset.x, -screenOffset.y); // consider the visible frame as being relative to the screen’s frame
	selectedArea.origin.y = NSHeight(controller.screen.frame) - NSHeight(selectedArea) - selectedArea.origin.y; // vertically flip the rectangle laid out within the screen frame
	selectedArea = CGRectOffset(selectedArea, screenOffset.x, screenOffset.y); // reapply the screen’s offset
	self.windowElement.frame = selectedArea;
}


-(IBAction)nextController:(id)sender {
	if (self.controllers)
		self.activeControllerIndex = (self.activeControllerIndex + 1) % self.controllers.count;
}

-(IBAction)previousController:(id)sender {
	if (self.controllers)
		self.activeControllerIndex = (self.activeControllerIndex > 0)?
			self.activeControllerIndex - 1
		:	self.controllers.count - 1;
}

@end
