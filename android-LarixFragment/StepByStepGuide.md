# Build a live streaming app with Larix SDK for Android

## Create an app project

First, create an app project in Android Studio.

1. Open Android Studio.
2. In the **Welcome to Android Studio** window, click **Start a new Android Studio project**.
3. In the **Choose your project** window, click **Empty Activity** on the **Phone and Tablet** tab.
4. In the Configure your project window, replace the Package name with the **com.softvelum.larixfragment**. and then click **Next**.
5. Select **Java** as the **Langauge**, select a minimum SDK version of API 18 or higher, and then click **Finish**.
6. Make sure the Larix SDK libraries are installed and the permissions are added to **AndroidManifest.xml** according to the instructions in [Configure an Android Studio project to use the Larix SDK](https://github.com/WMSPanel/larix-sdk-examples/blob/main/android-GettingStarted.md#configure-an-android-studio-project-to-use-the-larix-sdk).

## Add a camera preview holder

Next, add a camera preview holder.

In Android Studio, add new layout **afl_surface**.

Replace the contents of the **afl_surface.xml** file with the following code.
```
<?xml version="1.0" encoding="utf-8"?>

<com.softvelum.larixfragment.AspectFrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/preview_afl"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:layout_centerInParent="true">

    <SurfaceView
        android:id="@+id/surface_view"
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        android:layout_gravity="center" />

</com.softvelum.larixfragment.AspectFrameLayout>		
```

In Android Studio, add new Java class **AspectFrameLayout**.

Replace the contents of the **AspectFrameLayout.java** file with the following code.

```
package com.softvelum.larixfragment;

import android.content.Context;
import android.util.AttributeSet;
import android.util.Log;
import android.widget.FrameLayout;

/**
 * Layout that adjusts to maintain a specific aspect ratio.
 */
public final class AspectFrameLayout extends FrameLayout {
    private static final String TAG = "AFL";

    private double mTargetAspect = -1.0;        // initially use default window size

    public AspectFrameLayout(Context context) {
        super(context);
    }

    public AspectFrameLayout(Context context, AttributeSet attrs) {
        super(context, attrs);
    }

    /**
     * Sets the desired aspect ratio.  The value is <code>width / height</code>.
     */
    public void setAspectRatio(double aspectRatio) {
        if (aspectRatio < 0) {
            throw new IllegalArgumentException();
        }
        Log.d(TAG, "Setting aspect ratio to " + aspectRatio + " (was " + mTargetAspect + ")");
        if (mTargetAspect != aspectRatio) {
            mTargetAspect = aspectRatio;
            requestLayout();
        }
    }

    @Override
    protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        Log.d(TAG, "onMeasure target=" + mTargetAspect +
                " width=[" + MeasureSpec.toString(widthMeasureSpec) +
                "] height=[" + MeasureSpec.toString(heightMeasureSpec) + "]");

        // Target aspect ratio will be < 0 if it hasn't been set yet.  In that case,
        // we just use whatever we've been handed.
        if (mTargetAspect > 0) {
            int initialWidth = MeasureSpec.getSize(widthMeasureSpec);
            int initialHeight = MeasureSpec.getSize(heightMeasureSpec);

            // factor the padding out
            int horizPadding = getPaddingLeft() + getPaddingRight();
            int vertPadding = getPaddingTop() + getPaddingBottom();
            initialWidth -= horizPadding;
            initialHeight -= vertPadding;

            double viewAspectRatio = (double) initialWidth / initialHeight;
            double aspectDiff = mTargetAspect / viewAspectRatio - 1;

            if (Math.abs(aspectDiff) < 0.01) {
                // We're very close already.  We don't want to risk switching from e.g. non-scaled
                // 1280x720 to scaled 1280x719 because of some floating-point round-off error,
                // so if we're really close just leave it alone.
                Log.d(TAG, "aspect ratio is good (target=" + mTargetAspect +
                        ", view=" + initialWidth + "x" + initialHeight + ")");
            } else {
                if (aspectDiff > 0) {
                    // limited by narrow width; restrict height
                    initialHeight = (int) (initialWidth / mTargetAspect);
                } else {
                    // limited by short height; restrict width
                    initialWidth = (int) (initialHeight * mTargetAspect);
                }
                Log.d(TAG, "new size=" + initialWidth + "x" + initialHeight + " + padding " +
                        horizPadding + "x" + vertPadding);
                initialWidth += horizPadding;
                initialHeight += vertPadding;
                widthMeasureSpec = MeasureSpec.makeMeasureSpec(initialWidth, MeasureSpec.EXACTLY);
                heightMeasureSpec = MeasureSpec.makeMeasureSpec(initialHeight, MeasureSpec.EXACTLY);
            }
        }

        Log.d(TAG, "set width=[" + MeasureSpec.toString(widthMeasureSpec) +
                "] height=[" + MeasureSpec.toString(heightMeasureSpec) + "]");
        super.onMeasure(widthMeasureSpec, heightMeasureSpec);
    }
}
```

## Add broadcast fragment

In Android Studio, add new Java class **StreamerFragment**.

Replace the contents of the **StreamerFragmrnt.java** file with the following code.

```
public class StreamerFragment extends Fragment {

    private static final String TAG = "StreamerFragment";

    private static final String URI = "uri";
    private static final String CAMERA_ID = "camera_id";
    private static final String WIDTH = "width";
    private static final String HEIGHT = "heigth";

    private String mCameraId;
    private Streamer.Size mSize;
    private String mUri;

    public StreamerFragment() {
        // Required empty public constructor
    }

    /**
     * Use this factory method to create a new instance of
     * this fragment using the provided parameters.
     *
     * @param uri Stream uri.
     * @return A new instance of fragment SteamerFragment.
     */
    public static StreamerFragment newInstance(String cameraId, int width, int height, String uri) {
        StreamerFragment fragment = new StreamerFragment();
        Bundle args = new Bundle();
        args.putString(URI, uri);
        args.putInt(WIDTH, width);
        args.putInt(HEIGHT, height);
        args.putString(CAMERA_ID, cameraId);
        fragment.setArguments(args);
        return fragment;
    }

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Bundle args = getArguments();
        if (args != null) {
            mCameraId = args.getString(CAMERA_ID);
            mSize = new Streamer.Size(args.getInt(WIDTH), args.getInt(HEIGHT));
            mUri = getArguments().getString(URI);
        }
    }
}

```

Replace the contents of the activity_main.xml file with the following code.

```
<?xml version="1.0" encoding="utf-8"?>
<androidx.constraintlayout.widget.ConstraintLayout xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    tools:context=".MainActivity">

    <FrameLayout
        android:id="@+id/streamer"
        android:layout_width="match_parent"
        android:layout_height="match_parent"/>

</androidx.constraintlayout.widget.ConstraintLayout>
```

Add the code below to **ActivityMain.java**.

```
private void setFragment() {
    getSupportFragmentManager()
            .beginTransaction()
            .replace(R.id.streamer, StreamerFragment.newInstance(
                    "0",
                    1280, 720,
                    "rtmp://192.168.1.77:1937/live/demo"))
            .commit();
}
```

Where **"0"** is string id of default back camera, **1280x720** is video size and ***rtmp://192.168.1.77:1937/live/demo*** is stream target.

## Check for app permissions

Next, you must define the permissions the app requires.

Add the onCreate() and onRequestPermissionsResult() methods to the MainActivity class to check that the user has granted the app permission to access the camera and microphone. 

```
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
    if (requestCode == CAMERA_REQUEST) {
        for (int result : grantResults) {
            if (result == PackageManager.PERMISSION_DENIED) {
                return;
            }
        }
        setFragment();
    }
}

```

## Add and configure a broadcast

### 1. In the StreamerFragment.java file, include these import statements

```
import com.wmspanel.libstream.AudioConfig;
import com.wmspanel.libstream.CameraConfig;
import com.wmspanel.libstream.ConnectionConfig;
import com.wmspanel.libstream.Streamer;
import com.wmspanel.libstream.StreamerGL;
import com.wmspanel.libstream.StreamerGLBuilder;
import com.wmspanel.libstream.VideoConfig;
```

### 2. Add StreamerGL instance

In the StreamerFragment.java file, add StreamerGL object which is proxy object to Larix SDK.

```
private StreamerGL mStreamerGL;
```

### 3. Add the Streamer.Listener interface to StreamerFragment definition to monitor status updates and errors during live stream broadcast.

```
public class StreamerFragment extends Fragment implements Streamer.Listener {

    private Handler mHandler;

    private Streamer.CAPTURE_STATE mVideoCaptureState = Streamer.CAPTURE_STATE.FAILED;
    private Streamer.CAPTURE_STATE mAudioCaptureState = Streamer.CAPTURE_STATE.FAILED;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        mHandler = new Handler(Looper.getMainLooper());
        Bundle args = getArguments();
        if (args != null) {
            mCameraId = args.getString(CAMERA_ID);
            mSize = new Streamer.Size(args.getInt(WIDTH), args.getInt(HEIGHT));
            mUri = getArguments().getString(URI);
        }
    }

    @Override
    public void onAudioCaptureStateChanged(Streamer.CAPTURE_STATE state) {
        Log.d(TAG, "onAudioCaptureStateChanged, state=" + state);
        mAudioCaptureState = state;
    }

    @Override
    public void onVideoCaptureStateChanged(Streamer.CAPTURE_STATE state) {
        Log.d(TAG, "onVideoCaptureStateChanged, state=" + state);
        mVideoCaptureState = state;
    }

    @Override
    public void onConnectionStateChanged(int connectionId, Streamer.CONNECTION_STATE state, Streamer.STATUS status, JSONObject info) {
        Log.d(TAG, "onConnectionStateChanged, connectionId=" + connectionId + ", state=" + state + ", status=" + status);
    }

    @Override
    public void onRecordStateChanged(Streamer.RECORD_STATE state, Uri uri, Streamer.SAVE_METHOD method) {
        Log.d(TAG, "onRecordStateChanged, state=" + state);
    }

    @Override
    public void onSnapshotStateChanged(Streamer.RECORD_STATE state, Uri uri, Streamer.SAVE_METHOD method) {
        Log.d(TAG, "onSnapshotStateChanged, state=" + state);
    }

    @Override
    public Handler getHandler() {
        return mHandler;
    }

}
```
### 4. Add camera preview

In the StreamerFragment.java file, add below code.
```
protected AspectFrameLayout mPreviewFrame;

private SurfaceView mSurfaceView;
private SurfaceHolder mHolder;

@Override
public View onCreateView(LayoutInflater inflater, ViewGroup container,
                         Bundle savedInstanceState) {
    // Inflate the layout for this fragment
    ViewGroup root = (ViewGroup) inflater.inflate(R.layout.fragment_streamer, container, false);

    mPreviewFrame = root.findViewById(R.id.preview_afl);

    mSurfaceView = root.findViewById(R.id.surface_view);
    mSurfaceView.getHolder().addCallback(mPreviewHolderCallback);

    return root;
}

private final SurfaceHolder.Callback mPreviewHolderCallback = new SurfaceHolder.Callback() {
    @Override
    public void surfaceCreated(SurfaceHolder holder) {
        Log.v(TAG, "surfaceCreated()");

        if (mHolder != null) {
            Log.e(TAG, "SurfaceHolder already exists"); // should never happens
            return;
        }

        mHolder = holder;
        // We got surface to draw on, start streamer creation
        createStreamer();
    }

    @Override
    public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) {
        Log.v(TAG, "surfaceChanged() " + width + "x" + height);
        if (mStreamerGL != null) {
            mStreamerGL.setSurfaceSize(new Streamer.Size(width, height));
        }
    }

    @Override
    public void surfaceDestroyed(SurfaceHolder holder) {
        Log.v(TAG, "surfaceDestroyed()");
        mHolder = null;
        releaseStreamer();
    }

    private void releaseStreamer() {
        if (mStreamerGL != null) {
            mStreamerGL.release();
            mStreamerGL = null;
        }
    }
};
```
We will bind streamer lifecycle to preview surface: start immediately after fragment creation, stop on preview destroy (happens in onPause).

Real app may use no preview (background streaming).

### 5. Configure audio and video
```
private void createStreamer() {
    Log.v(TAG, "createStreamer()");
    if (mStreamerGL != null) {
        return;
    }

    final StreamerGLBuilder builder = new StreamerGLBuilder();

    builder.setContext(getContext());
    builder.setListener(this);

    // default config: 44.1kHz, Mono, CAMCORDER input
    builder.setAudioConfig(new AudioConfig());

    // default config: h264, 2 mbps, 2 sec. keyframe interval
    final VideoConfig videoConfig = new VideoConfig();
    videoConfig.videoSize = mSize;
    builder.setVideoConfig(videoConfig);

    builder.setCamera2(Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP);

    // preview surface
    builder.setSurface(mHolder.getSurface());
    builder.setSurfaceSize(new Streamer.Size(mSurfaceView.getWidth(), mSurfaceView.getHeight()));

    // streamer will start capture from this camera id
    builder.setCameraId(mCameraId);

    // we add single default back camera
    final CameraConfig cameraConfig = new CameraConfig();
    cameraConfig.cameraId = mCameraId;
    cameraConfig.videoSize = mSize;

    builder.addCamera(cameraConfig);

    builder.setVideoOrientation(videoOrientation());
    builder.setDisplayRotation(displayRotation());

    mStreamerGL = builder.build();

    if (mStreamerGL != null) {
        mStreamerGL.startVideoCapture();
        mStreamerGL.startAudioCapture();
    }

    updatePreviewRatio(mPreviewFrame, mSize);
}

private boolean isPortrait() {
    return getResources().getConfiguration().orientation == Configuration.ORIENTATION_PORTRAIT;
}

private int videoOrientation() {
    return isPortrait() ? StreamerGL.ORIENTATIONS.PORTRAIT : StreamerGL.ORIENTATIONS.LANDSCAPE;
}

private int displayRotation() {
    return getActivity().getWindowManager().getDefaultDisplay().getRotation();
}

private void updatePreviewRatio(AspectFrameLayout frame, Streamer.Size size) {
    if (frame != null && size != null) {
        frame.setAspectRatio(isPortrait() ? size.getVerticalRatio() : size.getRatio());
    }
}
```
Note that app should set preview's frame aspect ratio explicitly.

### 6. Start streaming

Configure callbacks to start streaming just after both audio and video capture were started successfully.
```
@Override
public void onAudioCaptureStateChanged(Streamer.CAPTURE_STATE state) {
    Log.d(TAG, "onAudioCaptureStateChanged, state=" + state);
    mAudioCaptureState = state;
    maybeCreateStream();
}

@Override
public void onVideoCaptureStateChanged(Streamer.CAPTURE_STATE state) {
    Log.d(TAG, "onVideoCaptureStateChanged, state=" + state);
    mVideoCaptureState = state;
    maybeCreateStream();
}

private void maybeCreateStream() {
    if (mStreamerGL != null
            && mVideoCaptureState == Streamer.CAPTURE_STATE.STARTED
            && mAudioCaptureState == Streamer.CAPTURE_STATE.STARTED) {
        // audio+video encoding is running -> create stream
        ConnectionConfig conn = new ConnectionConfig();
        conn.uri = mUri;
        mStreamerGL.createConnection(conn);
    }
}
```
