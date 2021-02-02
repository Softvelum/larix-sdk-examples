package com.softvelum.larixfragment;

import android.content.res.Configuration;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;

import androidx.fragment.app.Fragment;

import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.view.ViewGroup;

import com.wmspanel.libstream.AudioConfig;
import com.wmspanel.libstream.CameraConfig;
import com.wmspanel.libstream.ConnectionConfig;
import com.wmspanel.libstream.Streamer;
import com.wmspanel.libstream.StreamerGL;
import com.wmspanel.libstream.StreamerGLBuilder;
import com.wmspanel.libstream.VideoConfig;

import org.json.JSONObject;

/**
 * A simple {@link Fragment} subclass.
 * Use the {@link StreamerFragment#newInstance} factory method to
 * create an instance of this fragment.
 */
public class StreamerFragment extends Fragment implements Streamer.Listener {

    private static final String TAG = "StreamerFragment";

    private static final String URI = "uri";
    private static final String CAMERA_ID = "camera_id";
    private static final String WIDTH = "width";
    private static final String HEIGHT = "heigth";

    protected AspectFrameLayout mPreviewFrame;

    private SurfaceView mSurfaceView;
    private SurfaceHolder mHolder;

    private Handler mHandler;
    private StreamerGL mStreamerGL;

    private Streamer.CAPTURE_STATE mVideoCaptureState = Streamer.CAPTURE_STATE.FAILED;
    private Streamer.CAPTURE_STATE mAudioCaptureState = Streamer.CAPTURE_STATE.FAILED;

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
        mHandler = new Handler(Looper.getMainLooper());
        Bundle args = getArguments();
        if (args != null) {
            mCameraId = args.getString(CAMERA_ID);
            mSize = new Streamer.Size(args.getInt(WIDTH), args.getInt(HEIGHT));
            mUri = getArguments().getString(URI);
        }
    }

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
    };

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

    private void releaseStreamer() {
        if (mStreamerGL != null) {
            mStreamerGL.release();
            mStreamerGL = null;
        }
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

}