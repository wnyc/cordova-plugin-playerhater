package org.nypr.cordova.playerhaterplugin;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.URL;

public class ParserM3UToURL {

    public static String parse(String urlM3u) {

        String line=null;

        try {
            URL urlPage = new URL(urlM3u);
            HttpURLConnection connection = (HttpURLConnection) urlPage.openConnection();
            InputStream inputStream = connection.getInputStream();
            BufferedReader bufferedReader = new BufferedReader(new InputStreamReader(inputStream));

            StringBuffer stringBuffer = new StringBuffer();

            while((line = bufferedReader.readLine()) != null) {
                if (line.contains("http")){
                    connection.disconnect();
                    bufferedReader.close();
                    inputStream.close();
                    return line;
                }
                stringBuffer.append(line);
            }

            connection.disconnect();
            bufferedReader.close();
            inputStream.close();
        }catch (MalformedURLException e) {
            e.printStackTrace();
        } catch (IOException e) {
            e.printStackTrace();
        }
        return null;
    }
}