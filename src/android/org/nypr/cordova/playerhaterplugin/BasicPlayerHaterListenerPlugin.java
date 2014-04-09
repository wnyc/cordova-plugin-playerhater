package org.nypr.cordova.playerhaterplugin;

import org.prx.playerhater.PlayerHater;
import org.prx.playerhater.PlayerHaterListener;
import org.prx.playerhater.Song;
import org.prx.playerhater.plugins.PlayerHaterListenerPlugin;

import android.os.Bundle;
import android.util.Log;

public class BasicPlayerHaterListenerPlugin extends PlayerHaterListenerPlugin {

	protected static final String LOG_TAG = "BasicPlayerHaterListenerPlugin";
	
	protected BasicAudioPlayer mPlayer;
	
	public BasicPlayerHaterListenerPlugin(PlayerHaterListener listener, BasicAudioPlayer player) {
		super(listener);
		mPlayer = player;
	}

	public BasicPlayerHaterListenerPlugin(PlayerHaterListener listener, boolean echo) {
		super(listener, echo);
	}

	@Override
	public void onSongFinished(Song song, int reason) {
		Log.d(LOG_TAG, "onSongFinished--" + song.getTitle() + "; reason--" + reason + "; state=" +  this.getPlayerHater().getState() + "; Queue Position=" + this.getPlayerHater().getQueuePosition() + "; Queue Length: " + this.getPlayerHater().getQueueLength());
		// delete all items except the last item
		int length = this.getPlayerHater().getQueueLength();
		for(int i=1;i<length;i++) {
			this.getPlayerHater().removeFromQueue(1);	
		}	
		Bundle extra = song.getExtra();
		if (reason == PlayerHater.FINISH_SONG_END) {
			if (extra.getBoolean("isStream")) {
				this.getPlayerHater().emptyQueue(); // to trigger a 'stop' (PlayerHater doesn't trigger a stop when stream cuts out)
				mPlayer.onAudioStreamingError(1); // mp3 streaming error
				// define error codes when we have more than one code...
			} else {
				mPlayer.onCompleted();
			}
		} else if ( reason == PlayerHater.FINISH_ERROR ) {
			Log.d(LOG_TAG, "Song Finished Via Error--" + song.getUri().toString());
			mPlayer.playerInterrupted();
			if (extra.getBoolean("isStream")) {
				mPlayer.onAudioStreamingError(1); // aac streaming error
			}
		}
		super.onSongFinished(song, reason);
	}

	@Override
	public void onAudioStopped() {
		Log.d(LOG_TAG, "onAudioStopped; state=" +  this.getPlayerHater().getState() + "; Queue Position=" + this.getPlayerHater().getQueuePosition() + "; Queue Length: " + this.getPlayerHater().getQueueLength());		
		mPlayer.onStopped();
		super.onAudioStopped();
	}	
	
}
