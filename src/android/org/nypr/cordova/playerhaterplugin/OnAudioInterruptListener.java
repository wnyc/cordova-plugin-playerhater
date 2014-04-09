package org.nypr.cordova.playerhaterplugin;

public interface OnAudioInterruptListener {
	
    public enum INTERRUPT_TYPE { 
    	INTERRUPT_PHONE,
        INTERRUPT_HEADSET,
        INTERRUPT_OTHER_APP
      };
	
	public abstract void onAudioInterruptDetected(INTERRUPT_TYPE type, boolean trackInterrupt);
	public abstract void onAudioInterruptCompleted(INTERRUPT_TYPE type, boolean restart);
}
