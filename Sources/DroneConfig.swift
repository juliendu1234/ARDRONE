import Foundation

// MARK: - Configuration Structures (de l'ancien code)

struct DroneControls {
    static let takeoff = "X"
    static let land = "SQUARE"
    static let emergency = "TRIANGLE"
    static let resetEmergency = "CIRCLE"
    static let quit = "OPTIONS"
    // L2 and R2 are now available - sensitivity controlled via UI
    static let availableL2 = "L2"  // TODO: Assign new function
    static let availableR2 = "R2"  // TODO: Assign new function
    static let hoverMode = "SHARE"
    static let setHome = "L1"
    static let returnHome = "R1"
    static let cameraFront = "DPAD_UP"
    static let cameraBottom = "DPAD_DOWN"
    static let recordVideo = "DPAD_LEFT"
    static let takePhoto = "DPAD_RIGHT"
}

struct StickConfig {
    static let altitude = "LEFT_Y"
    static let yaw = "LEFT_X"
    static let pitch = "RIGHT_Y"
    static let roll = "RIGHT_X"
}

struct SensitivityConfig {
    static let startPercent: Float = 50
    static let minPercent: Float = 10
    static let maxPercent: Float = 100
    static let stepPercent: Float = 10
    static let deadzone: Float = 0.20
}

// MARK: - Flight Mode Configurations (like ARFreeFlight)

struct FlightModeConfig {
    var maxTilt: Int           // Max tilt angle in millidegrees (0.01°)
    var maxAltitude: Int       // Max altitude in millimeters
    var maxVerticalSpeed: Int  // Max vertical speed in mm/s
    var maxYawSpeed: Float     // Max yaw speed in °/s
    var gpsEnabled: Bool       // GPS enabled
    var outdoor: Bool          // Outdoor mode
    
    // Indoor preset (ARFreeFlight defaults for indoor)
    static let indoor = FlightModeConfig(
        maxTilt: 20000,        // 20° max tilt (safer for indoor)
        maxAltitude: 3000,     // 3 meters max altitude
        maxVerticalSpeed: 700, // 700 mm/s (0.7 m/s)
        maxYawSpeed: 100.0,    // 100°/s rotation
        gpsEnabled: false,
        outdoor: false
    )
    
    // Outdoor preset (ARFreeFlight defaults for outdoor)
    static let outdoor = FlightModeConfig(
        maxTilt: 30000,        // 30° max tilt (more agile)
        maxAltitude: 10000,    // 10 meters max altitude
        maxVerticalSpeed: 1000, // 1000 mm/s (1 m/s)
        maxYawSpeed: 200.0,    // 200°/s rotation
        gpsEnabled: true,
        outdoor: true
    )
    
    // User-adjustable limits (for UI sliders)
    static let limits = (
        maxTilt: (min: 5000, max: 30000),           // 5° to 30°
        maxAltitude: (min: 1000, max: 100000),      // 1m to 100m
        maxVerticalSpeed: (min: 200, max: 2000),    // 0.2 to 2 m/s
        maxYawSpeed: (min: 40.0, max: 350.0)        // 40 to 350 °/s
    )
}

struct HoverConfig {
    static let autoHoverEnabled = true
    static let inputTimeout: TimeInterval = 0.5
    static let hoverForceDelay: TimeInterval = 1.0
    static let disableAutoStabilization = true
}

struct GPSConfig {
    static let baudRate = 9600
    static let timeout: TimeInterval = 1.0
    static let homePrecision: Float = 5.0
    static let updateRate: TimeInterval = 1.0
    static let minSatellites = 4
}

struct DroneConfig {
    static let ip = "192.168.1.1"
    static let atPort: UInt16 = 5556
    static let navdataPort: UInt16 = 5554
    static let videoPort: UInt16 = 5555
    static let connectionTimeout: TimeInterval = 3.0
    static let reconnectInterval: TimeInterval = 5.0
}

// MARK: - ARDrone States

enum DroneState {
    case disconnected
    case connecting
    case connected
    case takingOff
    case flying
    case landing
    case emergency
    case hovering
    case returningHome
}

enum DroneFlightMode {
    case manual
    case hover
    case gps
    case returnToHome
}

struct DroneStatus {
    var state: DroneState = .disconnected
    var flightMode: DroneFlightMode = .manual
    var sensitivity: Float = SensitivityConfig.startPercent
    var batteryLevel: Float = 0
    var altitude: Float = 0
    var gpsEnabled: Bool = false
    var gpsLocation: (latitude: Double, longitude: Double)?
    var homeLocation: (latitude: Double, longitude: Double)?
    var satelliteCount: Int = 0
    var isEmergency: Bool = false
}

struct FlightInputs {
    var pitch: Float = 0
    var roll: Float = 0
    var yaw: Float = 0
    var gaz: Float = 0
    var lastInputTime: Date = Date()
}
