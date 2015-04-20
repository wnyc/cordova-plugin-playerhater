package org.nypr.cordova.playerhaterplugin;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import org.nypr.cordova.playerhaterplugin.BasicAudioPlayer.STATE;

import android.content.Context;
import android.content.Intent;
import android.content.res.AssetManager;
import android.net.ConnectivityManager;
import android.os.Environment;
import android.os.RemoteException;
import android.util.Log;


public class PlayerHaterPlugin extends CordovaPlugin implements OnAudioInterruptListener, OnAudioStateUpdatedListener{

	protected static final String LOG_TAG = "PlayerHaterPlugin";
	// protected static CordovaWebView mCachedWebView = null;

	protected PhoneHandler mPhoneHandler=null;
	protected BasicAudioPlayer mAudioPlayer=null;
	protected CallbackContext connectionCallbackContext;

	@Override
	public void initialize(CordovaInterface cordova, CordovaWebView webView) {
		Log.d(LOG_TAG, "PlayerHater Plugin initialize");
		super.initialize(cordova, webView);

		if(mPhoneHandler==null){
			mPhoneHandler=new PhoneHandler(this);
			mPhoneHandler.startListening(cordova.getActivity().getApplicationContext());
		}

		if(mAudioPlayer==null){
			mAudioPlayer=new BasicAudioPlayer(cordova.getActivity().getApplicationContext(), this);
		}

		this.connectionCallbackContext = null;

		// if ( mCachedWebView != null ) {
		// 	// this is a hack to destroy the old web view if it exists, which happens when audio is playing, the main app activity is 'killed' but the audio keeps playing, and then the app is restarted.
		// 	// performing the hack here instead of when the app activity is destroyed because the web view continues to function even though the activity is killed, so it will process javascript messages
		// 	// from the plugin telling it that the track is complete, so it will move to the next track if necessary...
		// 	Log.d(LOG_TAG, "Found cached web view -- destroying...");
		// 	String summary = "<html><body>Clear out JS</body></html>";
		// 	mCachedWebView.loadData(summary, "text/html", null);
		// }
		// mCachedWebView = webView;

		Log.d(LOG_TAG, "PlayerHater Plugin initialized");
	}

	@Override
	public void onReset() {
		Log.d(LOG_TAG, "PlayerHater Plugin onReset");
		_checkForWakeup(cordova.getActivity().getIntent()); // invoked when the activity is freshly launched...
		super.onReset();
	}

	@Override
	public void onNewIntent(Intent intent) {
		Log.d(LOG_TAG, "PlayerHater Plugin onNewIntent");
		super.onNewIntent(intent);
		_checkForWakeup(intent); // invoked when the acctivity is already running...
	}

	protected void _checkForWakeup(Intent intent){
		try {
			if (intent.getExtras().getBoolean("wakeup", false) && !mAudioPlayer.isPlaying()) {
				Log.d(LOG_TAG, "wakeup detected");

				JSONObject extra = new JSONObject(intent.getExtras().getString("extra"));
				JSONObject streams = extra.getJSONObject("streams");
				JSONObject info = extra.getJSONObject("info");
				JSONObject audio = extra.getJSONObject("audio");

				if (this._isConnected()) {
					_playStream(streams, info, audio);
				} else{
					String directory=_getDirectory(cordova.getActivity().getApplicationContext());
					String fileName = extra.getString("offline_sound");
					File f= new File(directory + fileName);
					if (!f.exists()){
						copyMp3(fileName);
					}
					info.put("title", "Q2 Default Wakeup Music");
					info.put("artist", "WQXR");
					_playAudioLocal(directory + fileName, info, 0, audio);
				}

				if (connectionCallbackContext!=null){
					JSONObject json=new JSONObject();
					json.put("type", "current");
					json.put("audio", audio);
					PluginResult pluginResult = new PluginResult(PluginResult.Status.OK, json);
					pluginResult.setKeepCallback(true);
					connectionCallbackContext.sendPluginResult(pluginResult);
				}

			}
		} catch (JSONException e) {
			if (connectionCallbackContext!=null){
				connectionCallbackContext.error(LOG_TAG + " error: invalid json");
			}

		} catch (Exception e) {
			if (connectionCallbackContext!=null){
				connectionCallbackContext.error(LOG_TAG + " error: " + e.getMessage());
			}
		}
	}

	private void copyMp3(String mp3ToCopy){

		// Open your mp3 file as the input stream
		try {
			InputStream myInput;
			AssetManager assetManager = cordova.getActivity().getApplicationContext().getAssets();
			myInput = assetManager.open(mp3ToCopy);

			// Path to the output file on the device
			String outFileName = _getDirectory(cordova.getActivity().getApplicationContext()) + mp3ToCopy;
			OutputStream myOutput = new FileOutputStream(outFileName);

			//transfer bytes from the inputfile to the outputfile
			byte[] buffer = new byte[1024];
			int length;
			while ((length = myInput.read(buffer))>0 ){
			   myOutput.write(buffer, 0, length);
			}

			//Close the streams => Better to have it in *final* block
			myOutput.flush();
			myOutput.close();
			myInput.close();
		} catch (IOException e) {
			Log.e(LOG_TAG, "Error Message:" + e.getMessage());
		}

	}

	@Override
	public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
		boolean ret=true;
		try {

			this.connectionCallbackContext = callbackContext;

			if(action.equalsIgnoreCase("init")){

				JSONObject audio=mAudioPlayer.checkForExistingAudio();
				PluginResult pluginResult=null;

				if (audio!=null) {
					JSONObject json=new JSONObject();
					json.put("type", "current");
					json.put("audio", audio);
					pluginResult = new PluginResult(PluginResult.Status.OK, json);
				} else {
					pluginResult = new PluginResult(PluginResult.Status.OK);

				}

				pluginResult.setKeepCallback(true);
				callbackContext.sendPluginResult(pluginResult);

			}else if (action.equals("playstream")) {

				JSONObject stationUrls = args.getJSONObject(0);
				JSONObject info = args.getJSONObject(1);
				JSONObject audioJson=null;
				if ( args.length() > 2 ) { audioJson = args.getJSONObject(2); }

				ret = _playStream(stationUrls, info, audioJson);

				PluginResult pluginResult = new PluginResult(PluginResult.Status.OK);
				pluginResult.setKeepCallback(true);
				callbackContext.sendPluginResult(pluginResult);

			}else if (action.equals("playremotefile")) {

				String file=args.getString(0);
				JSONObject info = args.getJSONObject(1);
				JSONObject audioJson=null;
				int position = 0;
				if ( args.length() > 2 ) { position = args.getInt(2); }
				if ( args.length() > 3 ) { audioJson = args.getJSONObject(3); }

				ret = _playRemoteFile(file, info, position, audioJson);

				PluginResult pluginResult = new PluginResult(PluginResult.Status.OK);
				pluginResult.setKeepCallback(true);
				callbackContext.sendPluginResult(pluginResult);
			}else if (action.equals("playfile")) {

				File file=new File(args.getString(0));
				JSONObject info = args.getJSONObject(1);
				JSONObject audioJson=null;
				int position = 0;
				if ( args.length() > 2 ) { position = args.getInt(2); }
				if ( args.length() > 3 ) { audioJson = args.getJSONObject(3); }
				if(file.exists()){
					ret = _playAudioLocal(args.getString(0), info, position, audioJson);
				} else {
					ret = _playRemoteFile(args.getString(0), info, position, audioJson);
				}

				PluginResult pluginResult = new PluginResult(PluginResult.Status.OK);
				pluginResult.setKeepCallback(true);
				callbackContext.sendPluginResult(pluginResult);
			}else if (action.equals("pause")) {

				_pauseAudio();

				PluginResult pluginResult = new PluginResult(PluginResult.Status.OK);
				pluginResult.setKeepCallback(true);
				callbackContext.sendPluginResult(pluginResult);

			}else if (action.equals("seek")) {

				int interval=args.getInt(0);
				_seekAudio(interval);

				PluginResult pluginResult = new PluginResult(PluginResult.Status.OK);
				pluginResult.setKeepCallback(true);
				callbackContext.sendPluginResult(pluginResult);

			}else if (action.equals("seekto")) {

				int pos=args.getInt(0);
				_seekToAudio(pos);

				PluginResult pluginResult = new PluginResult(PluginResult.Status.OK);
				pluginResult.setKeepCallback(true);
				callbackContext.sendPluginResult(pluginResult);

			}else if (action.equals("stop")) {

				_pauseAudio();

				PluginResult pluginResult = new PluginResult(PluginResult.Status.OK);
				pluginResult.setKeepCallback(true);
				callbackContext.sendPluginResult(pluginResult);

			}else if (action.equals("hardStop")) {

				_stopAudio();

				PluginResult pluginResult = new PluginResult(PluginResult.Status.OK);
				pluginResult.setKeepCallback(true);
				callbackContext.sendPluginResult(pluginResult);

			}else if (action.equals("setaudioinfo")) {

				JSONObject info = args.getJSONObject(0);
				_setAudioInfo(info);

				PluginResult pluginResult = new PluginResult(PluginResult.Status.OK);
				pluginResult.setKeepCallback(true);
				callbackContext.sendPluginResult(pluginResult);

			}else if (action.equals("getaudiostate")) {

				mAudioPlayer.fireAudioStateUpdated();

				PluginResult pluginResult = new PluginResult(PluginResult.Status.OK);
				pluginResult.setKeepCallback(true);
				callbackContext.sendPluginResult(pluginResult);

			}else{
				callbackContext.error(LOG_TAG + " error: invalid action (" + action + ")");
				ret=false;
			}
		} catch (JSONException e) {
			e.printStackTrace();
			callbackContext.error(LOG_TAG + " error: invalid json");
			ret = false;
		} catch (Exception e) {
			e.printStackTrace();
			callbackContext.error(LOG_TAG + " error: " + e.getMessage());
			ret = false;
		}
		return ret;
	}

	protected boolean _playStream(JSONObject stationUrls, JSONObject info, JSONObject audioJson)throws RemoteException, IOException, JSONException{

		String url = stationUrls.getString("android");

		String title = "";
		String artist = "";
		String imageUrl = null;
		boolean ret = false;

		if (this._isConnected()) {

			if(info!=null && info.has("name")){ title = info.getString("name");}
			if(info!=null && info.has("description")){ artist = info.getString("description");}
			if(info!=null && info.has("imageThumbnail")){
				JSONObject thumbnailImage = info.getJSONObject("imageThumbnail");
				if(thumbnailImage.has("url")){
					imageUrl = thumbnailImage.getString("url");
				}
			}

			_playAudio(url, title, artist, imageUrl, -1, audioJson, true);
			ret=true;
		} else {
			Log.d(LOG_TAG, "play stream failed: no connection");
		}

		return ret;
	}

	protected boolean _playAudioLocal(String file, JSONObject info, int position, JSONObject audioJson)throws RemoteException, IOException, JSONException{

		File f= new File(file);
		if (f.exists()) {
			// Set to Readable and MODE_WORLD_READABLE
			f.setReadable(true, false);
			Log.d(LOG_TAG, "is file readabel? " + f.canRead());
		}

		String title = null;
		String artist = null;
		String imageUrl = null;

		if(info.has("title")){ title = info.getString("title");}
		if(info.has("artist")){ artist = info.getString("artist");}
		if(info.has("imageThumbnail")){
			JSONObject thumbnailImage = info.getJSONObject("imageThumbnail");
			if(thumbnailImage.has("url")){
				imageUrl = thumbnailImage.getString("url");
			}
		}

		file = "file://" + file;
		_playAudio(file, title, artist, imageUrl, position, audioJson, false);

		return true;
	}

	protected boolean _playRemoteFile(String file, JSONObject info, int position, JSONObject audioJson)throws RemoteException, IOException, JSONException{
		String title = null;
		String artist = null;
		String imageUrl = null;
		boolean ret = false;

		if (this._isConnected()) {

			if(info.has("title")){ title = info.getString("title");}
			if(info.has("artist")){ artist = info.getString("artist");}
			if(info.has("imageThumbnail")){
				JSONObject thumbnailImage = info.getJSONObject("imageThumbnail");
				if(thumbnailImage.has("url")){
					imageUrl = thumbnailImage.getString("url");
				}
			}

			_playAudio(file, title, artist, imageUrl, position, audioJson, false);
			ret=true;
		} else {
			Log.d(LOG_TAG, "play remote file failed: no connection");
		}

		return ret;
	}

	public void _playAudio(String file, String title, String artist, String url, int position, JSONObject audioJson, boolean isStream) throws RemoteException, IOException, JSONException{
		Log.d(LOG_TAG, "Playing audio -- " + file);

		mAudioPlayer.startPlaying(file, title, artist, url, position, audioJson, isStream);
		//this.setAudioInfo(info);

	}

	protected void _pauseAudio() throws RemoteException{
		mAudioPlayer.pausePlaying();
	}

	protected void _seekAudio(int interval) throws RemoteException {
		mAudioPlayer.seekAudio(interval);
	}

	protected void _seekToAudio(int pos) throws RemoteException {
		mAudioPlayer.seekToAudio(pos);
	}

	protected void _stopAudio()throws RemoteException{
		Log.d(LOG_TAG, "Stopping audio");
		mAudioPlayer.stopPlaying();
	}

	protected void _setAudioInfo(JSONObject info)throws JSONException{
		String title = null;
		String artist = null;
		String url = null;

		if(info.has("title")){ title = info.getString("title");}
		if(info.has("artist")){ artist = info.getString("artist");}
		if(info.has("imageThumbnail")){
			JSONObject thumbnailImage = info.getJSONObject("imageThumbnail");
			if(thumbnailImage.has("url")){
				url = thumbnailImage.getString("url");
			}
		}

		mAudioPlayer.setAudioInfo(title, artist, url);
	}

	@Override
	public void onAudioInterruptDetected(INTERRUPT_TYPE type, boolean trackInterrupt) {
		Log.d(LOG_TAG,"Audio Interrupt Detected - Stop audio if necessary.");
		mAudioPlayer.interruptAudio(type,trackInterrupt);
	}

	@Override
	public void onAudioInterruptCompleted(INTERRUPT_TYPE type, boolean restart) {
		Log.d(LOG_TAG,"Audio Interrupt Completed - Restart audio if necessary.");

		try {
			mAudioPlayer.clearAudioInterrupt(type,restart);
		} catch (IOException e) {  // TODO - how to handle?
			Log.d(LOG_TAG, "onAudioInterruptCompleted error: " + e.getMessage() );
		}
	}

	@Override
	public void onAudioStateUpdated(STATE state) {
		Log.d(LOG_TAG,"onAudioStateUpdated " + state.ordinal() + "; " + state.toString() );
		if (this.connectionCallbackContext != null) {
			JSONObject o=new JSONObject();
			PluginResult result=null;
			try {
				o.put("type", "state");
				o.put("state", state.ordinal());
				o.put("description", state.toString());
				result = new PluginResult(PluginResult.Status.OK, o);
			} catch (JSONException e){
				result = new PluginResult(PluginResult.Status.ERROR, e.getMessage());
			} finally {
				result.setKeepCallback(true);
				this.connectionCallbackContext.sendPluginResult(result);
			}
		}

		if(state==STATE.MEDIA_STOPPED){
			onAudioProgressUpdated(0, 0);
		}
	}

	@Override
	public void onAudioProgressUpdated(int progress, int duration) {
		if (this.connectionCallbackContext != null) {
			JSONObject o=new JSONObject();
			PluginResult result=null;
			try {
				o.put("type", "progress");
				o.put("progress", progress);
				o.put("duration", duration);
				o.put("available", -1);
				result = new PluginResult(PluginResult.Status.OK, o);
			} catch (JSONException e){
				result = new PluginResult(PluginResult.Status.ERROR, e.getMessage());
			} finally {
				result.setKeepCallback(true);
				this.connectionCallbackContext.sendPluginResult(result);
			}
		}
	}

	@Override
	public void onAudioStreamingError(int reason) {
		if (this.connectionCallbackContext != null) {
			JSONObject o=new JSONObject();
			PluginResult result=null;
			try {
				o.put("type", "error");
				o.put("reason", reason);
				result = new PluginResult(PluginResult.Status.OK, o);
			} catch (JSONException e){
				result = new PluginResult(PluginResult.Status.ERROR, e.getMessage());
			} finally {
				result.setKeepCallback(true);
				this.connectionCallbackContext.sendPluginResult(result);
			}
		}
	}

	public static String _getDirectory(Context context){
		// one-stop for directory, so it only needs to be changed here once
		// check if we can write to the SDCard

		boolean externalStorageAvailable = false;
		boolean externalStorageWriteable = false;
		String state = Environment.getExternalStorageState();

		if (Environment.MEDIA_MOUNTED.equals(state)) {
			// We can read and write the media
			externalStorageAvailable = externalStorageWriteable = true;
			//Log.d(LOG_TAG, "External Storage Available (Readable and Writeable)");
		} else if (Environment.MEDIA_MOUNTED_READ_ONLY.equals(state)) {
			// We can only read the media
			externalStorageAvailable = true;
			externalStorageWriteable = false;
			Log.d(LOG_TAG, "External Storage Read Only");
		} else {
			// Something else is wrong. It may be one of many other states, but all we need
			//  to know is we can neither read nor write
			externalStorageAvailable = externalStorageWriteable = false;
			Log.d(LOG_TAG, "External Storage Not Available");
		}

		// if we can write to the SDCARD
		if (externalStorageAvailable && externalStorageWriteable) {
			return context.getExternalFilesDir(Environment.DIRECTORY_MUSIC).getAbsolutePath() + "/";
		}else{
			return null;
		}
	}

	protected boolean _isConnected() {
		ConnectivityManager connectivity = (ConnectivityManager) webView.getContext().getSystemService(Context.CONNECTIVITY_SERVICE);

		if (connectivity.getActiveNetworkInfo()==null){
			return false;
		} else if (connectivity.getActiveNetworkInfo().isConnected()) {
			return true;
		} else {
			return false;
		}
	}

}
