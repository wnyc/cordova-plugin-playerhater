package org.nypr.cordova.playerhaterplugin;


import org.nypr.cordova.playerhaterplugin.OnAudioInterruptListener.INTERRUPT_TYPE;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.telephony.TelephonyManager;
import android.util.Log;

// TODO - research if pause on phone ring is handled by default by the system

public class PhoneHandler {
	protected BroadcastReceiver mReceiver;
	protected Context mContext;
	protected static final String LOG_TAG = "PhoneHandler";
	public static final String TYPE_NONE = "NONE";
	
	OnAudioInterruptListener mListener;
	
	/**
	 * Constructor.
	 */
	public PhoneHandler()	{
		mReceiver=null;
		mContext=null;
		mListener=null;
	}

	/**
	 * Constructor.
	 */
	public PhoneHandler(OnAudioInterruptListener listener)	{
		mReceiver=null;
		mContext=null;
		mListener=listener;
	}	
	
	public void startListening(Context context){
		
		Log.d(LOG_TAG, "Starting Phone Listener");
		
		if(context!=null){
			// TODO - fail on invalid context?
			mContext=context;
		}
		
		// We need to listen to connectivity events to update navigator.connection
		IntentFilter intentFilter = new IntentFilter() ;
		intentFilter.addAction(TelephonyManager.ACTION_PHONE_STATE_CHANGED);
		if (this.mReceiver == null) {
			this.mReceiver = new BroadcastReceiver() {
				@Override
				public void onReceive(Context context, Intent intent) {	
					if(intent != null && intent.getAction().equals(TelephonyManager.ACTION_PHONE_STATE_CHANGED)) {
						// State has changed
						String phoneState = intent.hasExtra(TelephonyManager.EXTRA_STATE) ? intent.getStringExtra(TelephonyManager.EXTRA_STATE) : null;
						String state;
						// See if the new state is 'ringing', 'off hook' or 'idle'
						if(phoneState != null && phoneState.equals(TelephonyManager.EXTRA_STATE_RINGING)) {
							// phone is ringing, awaiting either answering or canceling
							state = "RINGING";
							Log.i(LOG_TAG,state);
			            	if(mListener!=null){
			            		mListener.onAudioInterruptDetected(INTERRUPT_TYPE.INTERRUPT_PHONE, true);
			            	}
						} else if (phoneState != null && phoneState.equals(TelephonyManager.EXTRA_STATE_OFFHOOK)) {
							// actually talking on the phone... either making a call or having answered one
							state = "OFFHOOK";
							Log.i(LOG_TAG,state);
			            	if(mListener!=null){
			            		mListener.onAudioInterruptDetected(INTERRUPT_TYPE.INTERRUPT_PHONE, true);
			            	}
						} else if (phoneState != null && phoneState.equals(TelephonyManager.EXTRA_STATE_IDLE)) {
							// idle means back to no calls in or out. default state.
							state = "IDLE";
							Log.i(LOG_TAG,state);
			            	if(mListener!=null){
			            		// restart = true; restart after phone call completed
			            		mListener.onAudioInterruptCompleted(INTERRUPT_TYPE.INTERRUPT_PHONE, true);
			            	}
						} else { 
							state = TYPE_NONE;
							Log.i(LOG_TAG,state);
			            	if(mListener!=null){
			            		// restart = true; restart after phone call completed
			            		mListener.onAudioInterruptCompleted(INTERRUPT_TYPE.INTERRUPT_PHONE, true);
			            	}
						}
					}
				}
			};
			// register the receiver... this is so it doesn't have to be added to AndroidManifest.xml
			mContext.registerReceiver(this.mReceiver, intentFilter);
		}
	}
	
	public void stopListening(){
		
		Log.d(LOG_TAG, "Stopping Phone Listener");
		
        if (this.mReceiver != null) {
            try {
                mContext.unregisterReceiver(this.mReceiver);
                this.mReceiver = null;
            } catch (Exception e) {
                Log.e(LOG_TAG, "Error unregistering phone listener receiver: " + e.getMessage(), e);
            }
        }	
	}
	
	/**
	 * Stop phone listener receiver.
	 */
	public void onDestroy() {
		
		Log.d(LOG_TAG, "Destroying Phone Listener");
		
		stopListening();
	}
	
	
}
