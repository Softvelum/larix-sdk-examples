package com.softvelum.larixfragment;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import android.Manifest;
import android.content.pm.PackageManager;
import android.os.Bundle;

public class MainActivity extends AppCompatActivity {

    private static final int CAMERA_REQUEST = 101;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        if (savedInstanceState == null) {
            checkPermissionsThenSetFragment();
        }
    }

    public void checkPermissionsThenSetFragment() {
        boolean cameraAllowed = ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED;
        boolean audioAllowed = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED;

        if (cameraAllowed && audioAllowed) {
            setFragment();
        } else {
            String[] permissions = new String[2];
            int n = 0;
            if (!cameraAllowed) {
                permissions[n++] = Manifest.permission.CAMERA;
            }
            if (!audioAllowed) {
                permissions[n] = Manifest.permission.RECORD_AUDIO;
            }
            ActivityCompat.requestPermissions(this, permissions, CAMERA_REQUEST);
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode,
                                           @NonNull String[] permissions,
                                           @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == CAMERA_REQUEST) {
            for (int result : grantResults) {
                if (result == PackageManager.PERMISSION_DENIED) {
                    return;
                }
            }
            setFragment();
        }
    }

    private void setFragment() {
        getSupportFragmentManager()
                .beginTransaction()
                .replace(R.id.streamer, StreamerFragment.newInstance(
                        "0",
                        1280, 720,
                        "rtmp://192.168.1.77:1937/live/demo"))
                .commit();
    }

}