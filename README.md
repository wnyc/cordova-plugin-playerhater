# PlayerHater Audio Player PhoneGap/Cordova Plugin

### Platform Support

This plugin supports PhoneGap/Cordova apps running on both iOS and Android.

### Version Requirements

This plugin is meant to work with Cordova 3.5.0+ and PlayerHater (Android)/PRXPlayer (iOS).

PlayerHater references:  
https://github.com/PRX/PlayerHater  
https://github.com/PRX/PRXPlayer  

## Installation

#### Automatic Installation using PhoneGap/Cordova CLI (iOS and Android)
1. Make sure you update your projects to Cordova iOS version 3.5.0+ before installing this plugin.

        cordova platform update ios
        cordova platform update android

2. Install this plugin using PhoneGap/Cordova cli:

        cordova local plugin add https://github.com/wnyc/cordova-plugin-playerhater.git

## Usage

    // all responses from the audio player are channeled through successCallback and errorCallback  

    // initialize the audio player - call after 'deviceready' event is fired  
    window.audioplayer.configure( successCallback, failureCallback);  

    // play a stream  
    window.audioplayer.playstream( successCallback,  
                                   failureCallback,  
                                   // stream urls to play on android/ios  
                                   {  
                                     android: "http://fm939.wnyc.org/wnycfm-app.aac",  
                                     ios: "http://fm939.wnyc.org/wnycfm-app.aac"}  
                                   },  
                                   // metadata used for iOS lock screen, Android 'Now Playing' notification  
                                   {  
                                     "title": "Cuomo; NJ Candidates; and Candy Etiquette",  
                                     "artist": "The Brian Lehrer Show",  
                                     "image": {  
                                       "url": "https://media2.wnyc.org/i/300/300/l/80/1/governor_andrew_cuomo.jpg"  
                                     },  
                                     "imageThumbnail": {  
                                       "url": "https://media2.wnyc.org/i/60/60/l/80/1/governor_andrew_cuomo.jpg"  
                                     },  
                                     "name": "WNYC 93.9 FM",  
                                     "description": "News, Culture & Talk"  
                                   },  
                                   // javascript-specific json represenation of audio to be played, which will be passed back to   
                                   // javascript via successCallback when a stream is launched from a local notification (eg, the  
                                   // alarm clock  
                                   extra  
                                 );  
  
    // play a file - looks first for the file on device, in the app's Documents/audio directory, and if not found there, plays the url  
    window.audioplayer.playfile( successCallback,  
                                 failureCallback,  
                                 "http://www.podtrac.com/pts/redirect.mp3/audio.wnyc.org/moneytalking/moneytalking20141031pod.mp3",  
                                 10, // position in track 10=10 seconds  
                                 // metadata used for iOS lock screen, Android 'Now Playing' notification  
                                 {  
                                   "title": "The Myth of the Self-Driving Car",  
                                   "artist": "Money Talking",  
                                   "image": {  
                                     "url": "https://media2.wnyc.org/i/1500/1208/c/80/1/google_self_driving_car_1.jpg"  
                                   },  
                                   "imageThumbnail": {}  
                                 },  
                                 extra // not currently used  
                               );  

    // pause audio playback  
    window.audioplayer.pause( successCallback, failureCallback);  

    // pause audio playback  
    window.audioplayer.stop( successCallback, failureCallback);  

    // seek forward in on-demand track  
    window.audioplayer.seek( successCallback, failureCallback, 10 ); // 10=10 seconds (verify this...)  

    // seek backward in on-demand track  
    window.audioplayer.seek( successCallback, failureCallback, -10 ); // -10=-10 seconds  
  
    // seek to a specific position in on-demand track  
    window.audioplayer.seekto( successCallback, failureCallback, 20 ); // 20=20 seconds  

    // request state of audio player  
    window.audioplayer.getaudiostate( successCallback, failureCallback ); // state returned via successCallback  

    // set audio player meta data (for lock screen on iOS) -- call this to change metadata for currently playing audio  
    window.audioplayer.setaudioinfo( successCallback,  
                                     failureCallback,  
                                     // metadata used for iOS lock screen, Android 'Now Playing' notification  
                                     {  
                                       "title": "Cuomo; NJ Candidates; and Candy Etiquette",  
                                       "artist": "The Brian Lehrer Show",  
                                       "image": {  
                                         "url": "https://media2.wnyc.org/i/300/300/l/80/1/governor_andrew_cuomo.jpg"  
                                       },  
                                       "imageThumbnail": {  
                                         "url": "https://media2.wnyc.org/i/60/60/l/80/1/governor_andrew_cuomo.jpg"  
                                       },  
                                       "name": "WNYC 93.9 FM",  
                                       "description": "News, Culture & Talk"  
                                     },  
                                   );  

    // callback method  
    var successCallback = function(result) {  
      console.log('audio callback ' + JSON.stringify(result));  
      if (result.type==='progress') {  
        console.log('progress/duration/available - ' + result.progress + '/' + result.duration + '/' + result.available); // available not currently supported  
      } else if (result.type==='state') {  
        console.log('status - ' + result.state + '/' + result.description);  
      } else if (result.type==='error') {  
        console.log('error - ' + result.reason);  
      } else if (result.type==='current') {  
        console.log('current audio ' + JSON.stringify(result.audio));  
      } else if (result.type==='next') {  
        console.log('skip to next audio track'); // typically fired by remote control/lock screen controls  
      } else if (result.type==='previous') {  
        console.log('skip to previous track'); // typically fired by remote/control/lock screen controls
      } else {  
        console.log('AudioCallback unhandled type (' + result.type + ')');  
      }  
    };  

    // audio states  
    MEDIA_NONE      : 0  
    MEDIA_STARTING  : 1  
    MEDIA_RUNNING   : 2  
    MEDIA_PAUSED    : 3  
    MEDIA_STOPPED   : 4  
    MEDIA_LOADING   : 5  
    MEDIA_COMPLETED : 6  
