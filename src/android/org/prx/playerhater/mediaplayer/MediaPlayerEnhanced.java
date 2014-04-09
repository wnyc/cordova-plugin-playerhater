package org.prx.playerhater.mediaplayer;

import java.io.IOException;
import java.util.Random;

import com.spoledge.aacdecoder.AACPlayer;
import com.spoledge.aacdecoder.MultiPlayer;
import com.spoledge.aacdecoder.PlayerCallback;
import android.media.AudioTrack;
import android.media.MediaPlayer;
import android.util.Log;

public class MediaPlayerEnhanced extends MediaPlayer implements PlayerCallback {
	

	protected static final String LOG_TAG = "MediaPlayerEnhanced";

	protected String mPath;
	protected boolean mIsAAC;
	protected MultiPlayer mMultiPlayer;
	protected long mStartTime;
	protected boolean mPaused;
	protected boolean mIsPlaying;
	protected boolean mIsLoading;
	protected int mDiagnosticId;
	protected String mLogTag;
	
	protected boolean mWaitingToPlay;
	
	protected OnErrorListener mErrorListener;
	protected OnPreparedListener mPreparedListener;
	protected OnCompletionListener mCompletionListener;
	protected OnBufferingUpdateListener mBufferingUpdateListener;
	protected OnInfoListener mInfoListener;
	protected OnSeekCompleteListener mSeekCompleteListener;
	
	public MediaPlayerEnhanced() {
		super();
		Random r = new Random();
		mDiagnosticId = r.nextInt();
		mLogTag = LOG_TAG + "-" + mDiagnosticId;
		Log.d(mLogTag, "Generated Diagnostic Id");
	}

	@Override
	public void prepareAsync() throws IllegalStateException {
		if ( mIsAAC ) {
			if (mMultiPlayer!=null && (mIsPlaying || mIsLoading)){
				Log.d(mLogTag, "stopping and destroying media player");
				//mMultiPlayer.setPlayerCallback(null);
				
				mWaitingToPlay=true;
				
				mMultiPlayer.stop();
				//mMultiPlayer=null;
			} else {
				mPaused=false;
				mIsPlaying=false;
				mIsLoading=true;
				mStartTime=0;
				if (mMultiPlayer==null){
					mMultiPlayer=new MultiPlayer(this, AACPlayer.DEFAULT_AUDIO_BUFFER_CAPACITY_MS * 3, AACPlayer.DEFAULT_DECODE_BUFFER_CAPACITY_MS);
				}
				Log.d(mLogTag, "prepareAsync--playAsync (" + mPath + ")");
				mMultiPlayer.playAsync(mPath);
			}
		} else {
			super.prepareAsync();
		}
	}

	@Override
	public void release() {
		super.release();
	}

	@Override
	public void setDataSource(String path) throws IOException, IllegalArgumentException, SecurityException, IllegalStateException {
		if ( path.substring(path.lastIndexOf('.') + 1).compareToIgnoreCase("aac") == 0 ) {
			Log.d(mLogTag, "setDataSource -- FOUND AAC -- " + path);
			mIsAAC = true;
			mPath = path;
		} else {
			mIsAAC=false;
			super.setDataSource(path);
		}
	}

	@Override
	public void playerAudioTrackCreated(AudioTrack audioTrack) {
		Log.d(mLogTag, "playerAudioTrackCreated(" + mPath + ")");
	}

	@Override
	public void playerException(Throwable t) {
		Log.d(mLogTag, "playerException (" + mPath + ")--" + t.getMessage());
		if ( mErrorListener!=null ) {
			mErrorListener.onError( this, 0, 0);
		}
		mPaused=false;
		mIsPlaying=false;
		mIsLoading=false;
	}

	@Override
	public void playerMetadata(String key, String value) {
		//Log.d(LOG_TAG, "playerMetadata(" + mPath + ")--" + key + "/" + value);
	}

	@Override
	public void playerPCMFeedBuffer(boolean isPlaying, int audioBufferSizeMs, int audioBufferCapacityMs) {
		//Log.d(LOG_TAG, "playerPCMFeedBuffer(" + mPath + "); buffer Size: " + audioBufferSizeMs + "; buffer capacity: " + audioBufferCapacityMs + "; isPlaying: " + isPlaying );
		mIsPlaying=isPlaying;
		if (mIsPlaying) {
			mIsLoading=false;
		}
	}

	@Override
	public void playerStarted() {
		Log.d(mLogTag, "playerStarted (" + mPath + ")");
		mStartTime = System.currentTimeMillis();
		mPaused=false;
		mIsLoading=false;
		mIsPlaying=true;
		if ( mPreparedListener!=null ) {
			mPreparedListener.onPrepared(this);
		}
	}

	@Override
	public void playerStopped(int perf) {
		Log.d(mLogTag, "playerStopped (" + mPath + ")");
		if ( mWaitingToPlay ) {
			mWaitingToPlay=false;
			mPaused=false;
			mIsPlaying=false;
			mIsLoading=true;
			mStartTime=0;
			//mMultiPlayer=new MultiPlayer(this, AACPlayer.DEFAULT_AUDIO_BUFFER_CAPACITY_MS * 3, AACPlayer.DEFAULT_DECODE_BUFFER_CAPACITY_MS);
			Log.d(mLogTag, "in playerStopped--prepareAsync--playAsync (" + mPath + ")");
			mMultiPlayer.playAsync(mPath);
			
		} else {
			mStartTime = 0;
			if (!mPaused) {
				// stopped in response to something besides 'pause'
				// likely a network drop
				// check network?
				
				// what error code to send????
				if ( mErrorListener!=null ) {
					Log.d(mLogTag, "firing onError on playerStopped");
					mErrorListener.onError( this, 0, 0);
				}
			}
			mPaused=false;
			mIsPlaying=false;
			mIsLoading=false;
		}
	}



	@Override
	public void setOnBufferingUpdateListener(OnBufferingUpdateListener listener) {
		mBufferingUpdateListener = listener;
		super.setOnBufferingUpdateListener(listener);
	}



	@Override
	public void setOnCompletionListener(OnCompletionListener listener) {
		mCompletionListener = listener;
		super.setOnCompletionListener(listener);
	}



	@Override
	public void setOnErrorListener(OnErrorListener listener) {
		mErrorListener = listener;
		super.setOnErrorListener(listener);
	}



	@Override
	public void setOnInfoListener(OnInfoListener listener) {
		mInfoListener = listener;
		super.setOnInfoListener(listener);
	}



	@Override
	public void setOnPreparedListener(OnPreparedListener listener) {
		mPreparedListener = listener;
		super.setOnPreparedListener(listener);
	}



	@Override
	public void setOnSeekCompleteListener(OnSeekCompleteListener listener) {
		mSeekCompleteListener = listener;
		super.setOnSeekCompleteListener(listener);
	}



	@Override
	public int getCurrentPosition() {
		if ( mIsAAC ) {
			//Log.d( LOG_TAG, "MediaPlayerEnhanced.getCurrentPosition() - aac");
			mMultiPlayer.getAudioBufferCapacityMs();
			mMultiPlayer.getDeclaredBitRate();
			mMultiPlayer.getDecodeBufferCapacityMs();
			
			if ( mStartTime > 0 ) {
				return (int) (System.currentTimeMillis() - mStartTime);
			} else {
				return 0;
			}
		} else {
			return super.getCurrentPosition();
		}
	}



	@Override
	public int getDuration() {
		if ( mIsAAC ) {
			//Log.d( LOG_TAG, "MediaPlayerEnhanced.getDuration() - aac");
			return 0;
		} else {
			return super.getDuration();
		}
	}



	@Override
	public boolean isPlaying() {
		if ( mIsAAC ) {
			Log.d( mLogTag, "MediaPlayerEnhanced.isPlaying() - aac = " + mIsPlaying);
			return mIsPlaying;
		} else {
			return super.isPlaying();
		}
	}



	@Override
	public void start() throws IllegalStateException {
		if ( mIsAAC ) {
			if (mPaused) {
				Log.d( mLogTag, "MediaPlayerEnhanced.start (" + mPath + ")" + "-- aac paused - restarting stream");
				this.prepareAsync();
			} else {
				Log.d( mLogTag, "MediaPlayerEnhanced.start (" + mPath + ")-- aac not paused - doing nothing");
			}
			mPaused=false;
		} else {
			super.start();
		}
	}

	@Override
	public void pause() throws IllegalStateException {
		if ( mIsAAC ) {
			Log.d( mLogTag, "MediaPlayerEnhanced.pause (" + mPath + ") - aac - stopping");
			if(mIsPlaying) {
				mMultiPlayer.stop();
			}
			mPaused = true;
			mIsPlaying=false;
			mIsLoading=false;
		} else {
			super.pause();
		}
	}
	

	@Override
	public void stop() throws IllegalStateException {
		if ( mIsAAC ) {
			Log.d( mLogTag, "MediaPlayerEnhanced.stop (" + mPath + ") - aac");
			if(mIsPlaying) {
				mMultiPlayer.stop();
			}
			mPaused=false;
			mIsPlaying=false;
			mIsLoading=false;
		} else {
			super.stop();
		}
	}

	@Override
	public void reset() {
		if( !mIsAAC ) {
			super.reset();
		}
	}
	
	
}
