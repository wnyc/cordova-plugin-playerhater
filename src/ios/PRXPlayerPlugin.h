//
//  PRXPlayerPlugin.h
//  NYPRNative
//
//  Created by Bradford Kammin on 4/2/14.
//
//

#import <Cordova/CDVPlugin.h>
#import <Cordova/CDVPluginResult.h>

#import "AudioStreamHandler.h"

@interface PRXPlayerPlugin : CDVPlugin
{
    AudioStreamHandler  * mAudioHandler;
    CDVReachability     * mNetworkStatus;
}

@property (nonatomic, retain)   AudioStreamHandler   * mAudioHandler;
@property (nonatomic, retain)   CDVReachability      * mNetworkStatus;

//- (void)init:(CDVInvokedUrlCommand*)command;
- (void)getaudiostate:(CDVInvokedUrlCommand*)command;
- (void)playstream:(CDVInvokedUrlCommand*)command;
- (void)playremotefile:(CDVInvokedUrlCommand*)command;
- (void)playfile:(CDVInvokedUrlCommand*)command;
- (void)pause:(CDVInvokedUrlCommand*)command;
- (void)stop:(CDVInvokedUrlCommand*)command;
- (void)seek:(CDVInvokedUrlCommand*)command;
- (void)seekto:(CDVInvokedUrlCommand*)command;
- (void)setaudioinfo:(CDVInvokedUrlCommand*)command;
- (void)setNetworkStatus:(CDVReachability*)reachability;

@end
