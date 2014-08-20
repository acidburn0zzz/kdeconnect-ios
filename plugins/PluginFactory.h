//
//  PluginFactory.h
//  kdeconnect-ios
//
//  Created by yangqiao on 5/11/14.
//  
//

#import <Foundation/Foundation.h>
#import "Plugin.h"
#import "common.h"

@class Device;

@protocol pluginFactoryDelegate <NSObject>
@optional
@end

@interface PluginFactory : NSObject

+ (id) sharedInstance;
- (Plugin*) instantiatePluginForDevice:(Device*)device pluginName:(NSString*)pluginName;
- (NSArray*) getAvailablePlugins;
- (NSArray*) getSupportedIncomingInterfaces;
- (NSArray*) getSupportedOutgoingInterfaces;
@end











