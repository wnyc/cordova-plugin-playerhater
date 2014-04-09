package org.nypr.cordova.playerhaterplugin;


public interface OnAudioStateUpdatedListener {
	public abstract void onAudioStateUpdated(BasicAudioPlayer.STATE state);
	public abstract void onAudioProgressUpdated(int progress, int duration);
	public abstract void onAudioStreamingError(int reason);
}
