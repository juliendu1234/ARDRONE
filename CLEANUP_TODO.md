# GPS/Home/RTH/FlightMode Cleanup TODO

## Still To Remove

### ARDroneController.swift
Lines to remove:
- Line 26: `private var rthTimer: Timer?`
- Lines 65-68: Navigation GPS properties (isNavigatingHome, navigationUpdateInterval, arrivalTolerance)
- Lines 409-420: Auto-set home point in NavData handler
- Lines 471-482: Auto-set home point in NavData option handler
- Lines 641-650: RTH logic in failsafe trigger
- Lines 655-685: `startAutomaticRTH()` function
- Lines 687-755: `executeRTHStep()` function
- Lines 824-838: `returnToHome()`, `clearHomePoint()` functions
- Lines 844-861: `calculateDistance()` function
- Lines 863-878: `calculateBearing()` function
- Lines 920-923: RTH status display in getDroneStateText()

### GamepadManager.swift
Lines to remove:
- Lines 264-270: L1 button comment and placeholder
- Lines 271-277: R1 button comment and placeholder
- Lines 399-407: L1 button handler (setHomePoint)
- Lines 425-433: R1 button handler (returnToHome)

### StatusWindowController.swift
Lines to remove:
- Lines 76-77: indoorButton, outdoorButton properties
- Lines 80-87: All slider properties (maxTilt, maxAltitude, maxVerticalSpeed, maxYawSpeed + labels)
- Lines 477-555: setupFlightModeButtons(), indoor/outdoor button setup, slider setup
- Lines 547-561: indoorButtonClicked(), outdoorButtonClicked(), updateFlightModeButtons()
- Lines 565-640: setupSlider() function and all slider change handlers
- Lines in controller mapping: Remove L1/R1 displays

### ATCommands.swift
Lines to remove:
- setOutdoorMode() function (around line 240)

## Commands Marked as Available
- L1: Available (TODO)
- R1: Available (TODO)  
- L2: Available (TODO)
- R2: Available (TODO)
