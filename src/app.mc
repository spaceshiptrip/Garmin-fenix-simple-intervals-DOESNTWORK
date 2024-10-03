using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.Sensor;
using Toybox.System;
using Toybox.Activity;

class IntervalApp extends WatchUi.WatchFace {

    var lowHrThreshold = 140;
    var lowHrTimeThreshold = 60000;  // 1 minute in milliseconds
    var heartRate = 0;
    var lastLowHrTime = null;
    var isRunning = false;           // Track if the session is running
    var timer = null;
    var sessionStartTime = null;

    var hrZones = [
        {zone: "Zone 1", min: 100, max: 120},
        {zone: "Zone 2", min: 121, max: 140},
        {zone: "Zone 3", min: 141, max: 160},
        {zone: "Zone 4", min: 161, max: 180},
        {zone: "Zone 5", min: 181, max: 200}
    ];

    //! Called when the app starts
    function onStart() {
        WatchUi.WatchFace.onStart();
        Sensor.enableHeartRate(onHeartRate);
        System.println("App Started");
    }

    //! Handle button presses for start/stop functionality
    function onKeyPress(key as Number) {
        if (key == WatchUi.KEY_START) {  // Top right button
            if (isRunning) {
                stopSession();
            } else {
                startSession();
            }
        }
    }

    //! Starts the session and begins interval monitoring
    function startSession() {
        isRunning = true;
        sessionStartTime = Time.now();
        startIntervalTimer();
        System.println("Session Started");
    }

    //! Stops the session and prompts the user to save or discard
    function stopSession() {
        isRunning = false;
        if (timer != null) {
            timer.stop();
        }
        promptSaveOrDiscard();
    }

    //! Prompts the user to save or discard the session
    function promptSaveOrDiscard() {
        var options = {"Save and End", "Discard and End"};
        WatchUi.Dialog.prompt("Session Stopped", "Do you want to save or discard?", options, method(:handleSaveOrDiscardSelection));
    }

    //! Handles the user's choice to save or discard the session
    function handleSaveOrDiscardSelection(index as Number) {
        if (index == 0) {  // Save and End
            saveSession();
        } else if (index == 1) {  // Discard and End
            discardSession();
        }
    }

    //! Saves the session data (activity gets uploaded to Garmin Connect during sync)
    function saveSession() {
        System.println("Session Saved");

        // Save session as an activity that can sync with Garmin Connect
        var activity = Activity.create(Activity.TYPE_RUNNING);
        activity.addEvent(Activity.Event.create(Activity.Event.TYPE_START, sessionStartTime));

        var stopTime = Time.now();
        activity.addEvent(Activity.Event.create(Activity.Event.TYPE_STOP, stopTime));
        activity.close();

        // End the app after saving
        WatchUi.requestApplicationExit();
    }

    //! Discards the session and ends the app
    function discardSession() {
        System.println("Session Discarded");
        WatchUi.requestApplicationExit();
    }

    //! Starts the interval timer
    function startIntervalTimer() {
        timer = new Timer.Timer();
        timer.start(1000, true, method(:checkLowHeartRate));
    }

    //! Called when a heart rate update is received
    function onHeartRate(info as Sensor.HeartRateInfo) {
        if (info != null) {
            heartRate = info.heartRate;
            WatchUi.requestUpdate();
        }
    }

    //! Checks if the heart rate is below the threshold for more than 1 minute
    function checkLowHeartRate() {
        if (isRunning && heartRate < lowHrThreshold) {
            if (lastLowHrTime == null) {
                lastLowHrTime = Time.now();
            } else if ((Time.now() - lastLowHrTime) > lowHrTimeThreshold) {
                System.vibrate(System.VIBE_ALERT);
                lastLowHrTime = null;
            }
        } else {
            lastLowHrTime = null;
        }
    }

    //! Called when the screen is refreshed
    function onUpdate(dc as Dc) {
        WatchUi.WatchFace.onUpdate(dc);

        dc.setColor(Graphics.COLOR_WHITE);
        dc.drawText(20, 30, Graphics.FONT_LARGE, "HR: " + heartRate);

        var hrZone = getHeartRateZone(heartRate);
        dc.drawText(20, 80, Graphics.FONT_MEDIUM, hrZone);

        for (var i = 0; i < hrZones.size(); i++) {
            var zone = hrZones[i];
            dc.drawText(20, 130 + i * 20, Graphics.FONT_SMALL, zone.zone + ": " + zone.min + "-" + zone.max + " bpm");
        }
    }

    //! Returns the current heart rate zone
    function getHeartRateZone(hr as Number) as String {
        foreach (zone in hrZones) {
            if (hr >= zone.min && hr <= zone.max) {
                return zone.zone;
            }
        }
        return "Unknown";
    }

    //! Called when the app stops
    function onStop() {
        WatchUi.WatchFace.onStop();
        Sensor.disableHeartRate();
        if (timer != null) {
            timer.stop();
        }
    }
}