//
//  Plugin.m
//  kdeconnect-ios
//
//  Created by yangqiao on 5/11/14.
//  Copyright (c) 2014 yangqiao. All rights reserved.
//

#import "Plugin.h"

@implementation PluginInfo

@synthesize _pluginName;
@synthesize _displayName;
@synthesize _description;
@synthesize _enabledByDefault;

- (PluginInfo*) initWithInfos:(NSString*)pluginName displayName:(NSString*)displayName description:(NSString*)description enabledByDefault:(BOOL)enabledBydefault
{
    _pluginName=pluginName;
    _displayName=displayName;
    _description=description;
    _enabledByDefault=enabledBydefault;
    return self;
}


@end

__strong static Plugin* _instance;

@implementation Plugin

@synthesize _device;
@synthesize _pluginInfo;

- (id) init
{
    if([super init]){
        
    }
    return self;
}

+ (Plugin*) getInstance
{
    return _instance;
}

- (BOOL) onCreate
{
    return true;
}

- (void) onDestroy
{
}

- (BOOL) onPackageReceived:(NetworkPackage *)np
{
    return false;
}

- (void) dealloc
{
    
}
@end
