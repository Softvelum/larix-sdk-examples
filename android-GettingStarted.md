This document is provided as part of Larix Broadcaster SDK for Android. It's shown here as a reference for users who plan purchasing the SDK.

# Download and install Larix SDK for Android

Download and install Larix SDK for Android, set up your Android Studio development environment, and start using the sample apps.

## Contents

1. [Requirements for Larix SDK for Android](#requirements-for-larix-sdk-for-android)
2. [Download and install the tools](#download-and-install-the-tools)
3. [Configure an Android Studio project to use the Larix SDK](#configure-an-android-studio-project-to-use-the-larix-sdk)
4. [Practice with the SDK sample app](#practice-with-the-sdk-sample-app)

## Requirements for Larix SDK for Android

Developing apps with the Larix SDK for Android requires Android 4.3 (API level 18) or later for broadcasting.

Android Studio 4.1 or later is also required.

Running and debugging Larix SDK apps using a device emulator isn't recommended due to the wide variance in functionality between the software-based audio and video codecs used by the emulator and the hardware-based codecs installed on most devices.

## Download and install the tools

[Download and install the current version of Android Studio.](https://developer.android.com/studio/index.html) If you already have Android Studio installed, check for updates to make sure you're running the current version.

#### 1. Download the latest build of Larix SDK for Android.

#### 2. Expand the downloaded .zip file, which contains the following files and folders:

**libs/libstream-release.aar**

The Android archive file that contains mobile broadcasting library.

**libs/libudpsender-release.aar**

The Android archive file that contains UDP (SRT and RIST) streaming libraries.

**/LarixBroadcaster**

Full source code of Larix Broadcaster app.

**/LarixScreencaster**

Full source code of Larix Screencaster app.

**/LarixFragment**

A sample application that demonstrates minimal setup to get started with SDK.

**/EncodeAndMuxTest**

Draw simple animation using OpenGL surface, encode it and broadcast.

**/Camera2demo**

Use camera2 api to get preview, apply sepia filter, encode processed image and broadcast it.

**/CameraFX**

Use camera or camera2 api to get preview, apply filters, encode processed image and broadcast it.

**/BackgroundCamera** - advanced example of camera implementation on app side;

* Record camera preview and broadcast from background service;
* Draw logo;
* Draw text. 

**/DualStreamer**

Run two instances of streamer to record HD video and broadcast SD video simultaneously.

**/gles/libgrafika**

A collection of OpenGL wrappers used in **Camera2Demo** and **BackgroundCamera** projects. Based on [grafika](https://github.com/google/grafika/).

## Configure an Android Studio project to use the Larix SDK

To develop Android apps with the Larix SDK, configure an Android Studio project to recognize the Larix SDK libraries and add the appropriate permissions to the app's manifest file.

1. In Android Studio, create a project. See Create an app project. 

2. In the file system, copy **libstream-release.aar** and **libudpsender-release.aar** from the expanded .zip file to the project's **libs** folder. By default, the **libs** folder is located at ***[project_root]/app/libs***.

3. In Android Studio, open **build.gradle (Module: app)**, which you can find in the Gradle Scripts section of the project view.

4. In the editor window, add a dependency for the SDK library by copying the following code into the file as described:

```
repositories {
    flatDir {
        dirs 'libs'
    }
}

dependencies {
    implementation(name: 'libstream-release', ext: 'aar')
    implementation(name: 'libudpsender-release', ext: 'aar')
}
```

5. In the tool window, navigate to **app/manifests** and open the **AndroidManifest.xml** file.

6. Add the following permissions below the package declaration, above the application element:

```
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />

```

## Practice with the SDK sample app

[Build a live streaming app with Larix SDK for Android](https://github.com/WMSPanel/larix-sdk-examples/blob/main/android-LarixFragment/StepByStepGuide.md)


