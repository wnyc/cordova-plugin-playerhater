package org.nypr.cordova.playerhaterplugin;

import java.io.IOException;
import java.util.HashSet;
import android.content.Context;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;

import org.json.JSONException;
import org.json.JSONObject;
import org.nypr.cordova.playerhaterplugin.OnAudioStateUpdatedListener;
import org.nypr.cordova.playerhaterplugin.OnAudioInterruptListener.INTERRUPT_TYPE;
import org.prx.playerhater.PlayerHater;
import org.prx.playerhater.PlayerHaterListener;
import org.prx.playerhater.Song;
import org.prx.playerhater.songs.Songs;
import org.prx.playerhater.util.IPlayerHater;

public class BasicAudioPlayer implements PlayerHaterListener  {


	protected static final String LOG_TAG = "BasicAudioPlayer";
	
	protected Context mContext;
	protected PlayerHater mHater;
	protected Song mPlaying;
	protected HashSet<INTERRUPT_TYPE> mPendingInterrupts;
	protected OnAudioStateUpdatedListener mListener;
	protected STATE mLastStateFired;
	
    // AudioPlayer states
    public enum STATE { MEDIA_NONE,
                        MEDIA_STARTING,
                        MEDIA_RUNNING,
                        MEDIA_PAUSED,
                        MEDIA_STOPPED,
                        MEDIA_LOADING,
                        MEDIA_COMPLETED
                      };
	        

   public BasicAudioPlayer(Context context, OnAudioStateUpdatedListener listener) {
	   mContext=context;
	   mListener=listener;
	   mPendingInterrupts=new HashSet<INTERRUPT_TYPE>();
	   mHater = PlayerHater.bind(mContext);
	   mHater.setLocalPlugin( new BasicPlayerHaterListenerPlugin( this, this ) );
   }
   
   public JSONObject checkForExistingAudio() throws JSONException{
	   Log.d("LOG_TAG", "On startup, checking service for pre-existing audio..." );
     JSONObject json = null;
	   if( mHater.isPlaying() || mHater.isLoading() ){
		   Song song = mHater.nowPlaying();
		   if( song!=null ) {
			   mPlaying=song;
			   Bundle playing = song.getExtra();
			   Log.d(LOG_TAG, "playing/loading:");
			   String data=playing.getString("audioJson");
			   json = new JSONObject( data );
			   json.put( "progress", mHater.getCurrentPosition() );
		   }
	   }
	   return json;	  
   }
   
	@Override
	public void onStopped() {
		Log.d(LOG_TAG, "PlayerHater.onStopped");
		fireState(STATE.MEDIA_STOPPED); // IPlayerHater does not contain a 'stopped' state -- roll our own
	}
	
	public void onCompleted() {
		Log.d(LOG_TAG, "PlayerHater.onCompleted");
		fireState(STATE.MEDIA_COMPLETED); //// IPlayerHater does not contain a 'completed' state, either
	}
	
	@Override
	public void onStreaming(Song song) {
		Log.d(LOG_TAG, "PlayerHater.onStreaming");
		fireState();
	}
	
	@Override
	public void onPaused(Song song) {
		Log.d(LOG_TAG, "PlayerHater.onPaused");
		fireState();
	}
	
	@Override
	public void onLoading(Song song) {
		Log.d(LOG_TAG, "PlayerHater.onLoading");
		fireState();
	}
	
	@Override
	public void onPlaying(Song song, int progress) {
    	if(mLastStateFired != STATE.MEDIA_RUNNING){
    		refreshAudioInfo();
    	}
		
		fireState();
		
    	if(mHater!=null && mListener!=null ){
    		int position=0;
    		int duration=0;
    		try { 
    			position=mHater.getCurrentPosition();
    		} catch (Exception e) {
    			e.printStackTrace();
    			position=0;
    		}
    		try {
    			duration=mHater.getDuration();
    		} catch (Exception e) {
    			e.printStackTrace();
    			duration=0;
    		}
        	mListener.onAudioProgressUpdated(position, duration);
        }
	}
	
	public void onAudioStreamingError(int reason){
		mListener.onAudioStreamingError(reason);
	}
	
	public boolean isPlaying(){
		// use mHater.isPlaying()/mHater.isLoading() -- test to make sure they work
		
		//return getState().equals(STATE.MEDIA_LOADING) || getState().equals(STATE.MEDIA_RUNNING) || getState().equals(STATE.MEDIA_PAUSED) || getState().equals(STATE.MEDIA_STARTING);
		return mHater!=null && (mHater.isPlaying() || mHater.isLoading());
	}
	
	public void setAudioInfo(String title, String artist, String url){
		if(mPlaying!=null){
			/*
			 * TODO -- figure out a way to update notification data mid-stream
			 * 
			Bundle bundle = new Bundle();
			bundle.putString("title", title);
			bundle.putString("artist", artist);
			bundle.putParcelable("uri", Uri.parse(url));
			mPlaying = Songs.fromBundle(bundle);*/
			
			refreshAudioInfo();
		}
	}
	
	public void refreshAudioInfo(){
		if(mHater!=null){
			//Log.d(LOG_TAG, "NOT REFRESHING AUDIO INFO");
			/*
			mHater.setTitle(mPlaying.getTitle());
			mHater.setArtist(mPlaying.getArtist());
			//if(url!=null){
			//	Uri uri=Uri.parse(url);
				mHater.setAlbumArt(mPlaying.getAlbumArt());
			//
			 */
		}
	}
	
	public void startPlaying(String file, String title, String artist, String url, int position, JSONObject audioJson, boolean isStream)throws IOException{
		Log.d(LOG_TAG,"Starting Audio--" + file );
		
		// handle m3u file
		if (file.toUpperCase().endsWith("M3U")){
			Log.d(LOG_TAG, "M3U found, parsing...");
			String parsed = ParserM3UToURL.parse(file);
			if (parsed!=null) {
				file = parsed;
				Log.d(LOG_TAG, "Using parsed url--" + file);
			} else {
				Log.d(LOG_TAG, "No stream found in M3U");
			}
		}
		
		// create a Uri object for audio
		Uri uri = Uri.parse(file);

		// create a Uri object of artwork
		Uri artworkUri=null;
		if ( url != null ) {
			artworkUri = Uri.parse(url);
		}
		
		// create a Bundle, used to create Song
		Bundle bundle = new Bundle();
		bundle.putString("title", title);
		bundle.putString("artist", artist);
		if (artworkUri!=null){
			bundle.putParcelable("album_art", artworkUri);
		}
		bundle.putParcelable("uri", uri);
		Bundle extra = new Bundle();
		extra.putString("audioJson", audioJson.toString()); // store in bundle as a string
		extra.putBoolean("isStream", isStream);
		bundle.putBundle("extra", extra);
		
		// create the Song object
		Song song = Songs.fromBundle(bundle);
		
		// play the Song
		startPlaying(song, position);
	}
	
	protected void startPlaying(Song song, int position)throws IOException{
		// TODO - perform an inventory of interrupts
		
		Log.d(LOG_TAG,"Starting Stream from Song--" + Uri.decode( song.getUri().toString() ) );
		
		if(mHater==null){
			// double-check -- this action is initially called in constructor
			mHater = PlayerHater.bind(mContext);
		}
		
		if(mPendingInterrupts.size()>0){
			// if stream is started when an audio interrupt(s) exists,
			// don't play, store new stream for when interrupt(s) go away
			// stream will be (re)started by resumeAudio
			mPlaying = song;
			
		}else{
			if( !song.getUri().getLastPathSegment().toLowerCase().endsWith("aac") ) { // ugly. remove when 'pause' aac is implemented
			
				if(mPlaying!=null && !song.getUri().equals( mPlaying.getUri() ) && isPlaying() ){
					Log.d(LOG_TAG,"Interupting current playback to launch new...");
					Log.d(LOG_TAG,"New URI : " + song.getUri().toString() );
					Log.d(LOG_TAG,"Old URI : " + mPlaying.getUri().toString() );
					
					// new stream passed in that is different the current stream, 
					// and the current stream is loading, paused, or playing
					
					// stop the current stream
					//mHater.stop();
					mPlaying=song;
					if ( position > 0 ) {
						mHater.play(mPlaying, position*1000);
					} else {
						mHater.play(mPlaying);
					}
				}else if( mPlaying!=null && song.getUri().equals( mPlaying.getUri() ) && mHater.getState() == IPlayerHater.STATE_PAUSED ){
					// resume audio
					Log.d(LOG_TAG,"Resuming Playback...");
					mHater.play();
				}else if(!isPlaying()){
					// launch audio
					Log.d(LOG_TAG,"Launching Playback...");
					mPlaying=song;
					if ( position > 0 ) {
						mHater.play(mPlaying, position*1000);
					} else {
						mHater.play(mPlaying);
					}
				}else{
					Log.d(LOG_TAG, "not playing because playerhater status is " + mHater.getState());
				}
			} else {
				// ugly. remove when 'pause' aac is implemented
				
				// launch audio
				Log.d(LOG_TAG,"Launching Playback...");
				mPlaying=song;
				if ( position > 0 ) {
					mHater.play(mPlaying, position*1000);
				} else {
					mHater.play(mPlaying);
				}
			}
		}
	}
	
	public void pausePlaying(){

		// make sure audio is playing
		// check queue position as a secondary check -- an edge condition exists where if a song completes, and pause is called afterward, a crash occurs 
		if(mHater.isPlaying() && mHater.getQueuePosition() > 0 ){
			mHater.pause();
		}else {
			Log.d(LOG_TAG, "No audio playing -- skipping pause. isPlaying=" + mHater.isPlaying() + "; getQueuePosition()=" + mHater.getQueuePosition());
		}
	}
	
	public void playerInterrupted() {
		Log.d(LOG_TAG, "Firing MEDIA_PAUSED on stream finish on error");
		this.fireTransientState(STATE.MEDIA_PAUSED);
	}
	
	public void seekAudio(int interval){
		Log.d(LOG_TAG, "Seek Audio. Interval: " + interval );
		if(mHater.getDuration() > 0){
			if(isPlaying()){
				int currentPosition = mHater.getCurrentPosition(); // ms
				int newPosition = currentPosition + (interval);
				Log.d(LOG_TAG, "Current/New Positions: " + currentPosition + "/" + newPosition);
				mHater.seekTo(newPosition);
			}else{
				Log.d(LOG_TAG, "Not currently playing, so not seeking");
			}
		}else{
			Log.d(LOG_TAG, "Seek not available.");
		}
	}
	
	public void seekToAudio(int pos){
		Log.d(LOG_TAG, "Seek Audio. Position: " + pos );
		if(mHater.getDuration() > 0){
			if(isPlaying()){
				mHater.seekTo(pos);
			}else{
				Log.d(LOG_TAG, "Not currently playing, so not seeking");
			}
		}else{
			Log.d(LOG_TAG, "Seek not available.");
		}
	}
	
	public void stopPlaying(){
		Log.d(LOG_TAG,"Stopping Stream");
		if(mHater!=null){
			if( mHater.isPlaying() || mHater.getState() == IPlayerHater.STATE_PAUSED) {
				mHater.stop();
			}
		}
		mPlaying=null;
		// clear interrupts
		mPendingInterrupts.clear();
	}
	
	
	public void interruptAudio(INTERRUPT_TYPE type, boolean trackInterrupt){
		// stop audio. store the fact that this interrupt is pending
		if(!mPendingInterrupts.contains(type)  && mHater.isPlaying() ){		
			Log.d(LOG_TAG, "Audio interrupted - stop audio - " + type);
			if(trackInterrupt){
				// if tracked, don't allow stream resumption until interrupt goes away
				mPendingInterrupts.add(type);
				pausePlaying();
			}else{
				stopPlaying();
			}
		}
	}
	
	public void clearAudioInterrupt(INTERRUPT_TYPE type, boolean restart)throws IOException{
		if(mPendingInterrupts.contains(type)){
			Log.d(LOG_TAG, "Audio interrupt over - " + type);
			
			// remove this interrupt
			mPendingInterrupts.remove(type);
			// make sure there are no other interrupts
			if(mPendingInterrupts.size()==0){
				if(restart){
					Log.d(LOG_TAG, "Audio interrupt over - restart audio - " + type);

					startPlaying(mPlaying,0);
				}
			}else{
				Log.d(LOG_TAG, "Interrupts still pending");
			}
		}
	}
	
	
	protected void fireTransientState(STATE state){
		if(mListener!=null){
			mListener.onAudioStateUpdated(state);
		}
	}
	
	protected void fireState(STATE state){
		if(mListener!=null){
			if(!state.equals(mLastStateFired)){
				mListener.onAudioStateUpdated(state);
			}
			mLastStateFired=state;
		}
	}
	
	protected void fireState(){
		if(mListener!=null){
			STATE state=getState();
			fireState(state);
			mLastStateFired=state;
		}
	}
	
	protected STATE getState(){
		return translateState();
	}
	
	protected STATE translateState(){
		STATE state=STATE.MEDIA_NONE;

		if(mHater!=null){
			switch(mHater.getState()){
				case IPlayerHater.STATE_IDLE:
					state=STATE.MEDIA_NONE;
					break;
				case IPlayerHater.STATE_LOADING: // player service is loading, not track
					state=STATE.MEDIA_LOADING;
					break;
				case IPlayerHater.STATE_PLAYING:
				case IPlayerHater.STATE_STREAMING:
					state=STATE.MEDIA_RUNNING;
					break;
				case IPlayerHater.STATE_PAUSED:
					state=STATE.MEDIA_PAUSED;
					break;
				case IPlayerHater.STATE_INVALID:
					//state=STATE.; // ?? what here?
					break;
			}
		}
		return state;
	}
	
	public void fireAudioStateUpdated(){
		if(mListener!=null){
			mListener.onAudioStateUpdated(getState());
		}
	}
}
