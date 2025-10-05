import Foundation
import Network

/// Comprehensive controller for AR.Drone 2.0 with full GPS, hover, and sensitivity management
class ARDroneController {
    
    // Network connections
    private var commandConnection: NWConnection?
    private var navigationConnection: NWConnection?
    
    // State tracking
    private var isNetworkReady = false
    private var isReceivingNavData = false
    private var lastNavDataTime: Date?
    private var lastVideoFrameTime: Date?
    private var networkLogicalConnected = false
    
    // Validation des navdata
    private var isReceivingValidNavdata = false
    private var lastValidNavdataTime: Date?
    
    // Timers
    private var commandTimer: Timer?
    private var failsafeTimer: Timer?
    private var reconnectionTimer: Timer?
    private var rthTimer: Timer?
    private var hoverTimer: Timer?
    
    // Failsafe system
    private enum FailsafeState {
        case normal
        case reconnecting
        case returningToHome
        case landing
    }
    
    private var failsafeState: FailsafeState = .normal
    private var reconnectionAttempts = 0
    private let maxReconnectionAttempts = 6
    private var failsafeStartTime: Date?
    private let failsafeTimeout: TimeInterval = 60.0
    
    // AT Commands
    private let atCommands = ATCommands()
    
    // Current control state + FlightInputs
    private var flightInputs = FlightInputs()
    private var roll: Float = 0.0
    private var pitch: Float = 0.0
    private var yaw: Float = 0.0
    private var gaz: Float = 0.0
    
    // Hover management
    private var isAutoHoverActive = false
    private var lastInputTime: Date?
    
    // Telemetry
    private(set) var currentNavData: NavData?
    private let navDataParser = NavDataParser()
    var onNavDataReceived: ((NavData) -> Void)?
    
    // Video
    let videoHandler = VideoStreamHandler()
    
    // Navigation GPS réelle
    private var isNavigatingHome = false
    private let navigationUpdateInterval: TimeInterval = 0.2
    private let arrivalTolerance: Double = 3.0
    
    // Configuration
    private var isConfigured = false
    private let sessionId = "00000000"
    private let userId = "00000000"
    private let applicationId = "00000000"
    
    // Callbacks
    var onFailsafeActivated: ((String) -> Void)?
    var onFailsafeRecovered: (() -> Void)?
    var onConnectionLost: (() -> Void)?
    var onCriticalWarning: ((String) -> Void)?
    var onInfoMessage: ((String) -> Void)?
    
    init() {
        print("🚁 ARDrone Controller initialized")
        setupVideoHandler()
    }
    
    // MARK: - Video Handler Setup
    
    private func setupVideoHandler() {
        videoHandler.onFrameReceived = { [weak self] frameData in
            self?.lastVideoFrameTime = Date()
        }
        
        videoHandler.onVideoError = { error in
            print("❌ Video error: \(error)")
        }
        
        videoHandler.onRecordingStarted = { url in
            print("🎥 Recording started: \(url.lastPathComponent)")
        }
        
        videoHandler.onRecordingStopped = { url in
            print("⏹️ Recording stopped: \(url.lastPathComponent)")
        }
    }
    
    // MARK: - Connection Status
    
    func isConnectedToDrone() -> Bool {
        // Vérification 1 : Sockets ouverts
        guard commandConnection != nil, navigationConnection != nil else {
            return false
        }
        
        // Vérification 2 : Vidéo reçue récemment (PRIORITÉ)
        if let lastVideo = lastVideoFrameTime {
            let timeSinceVideo = Date().timeIntervalSince(lastVideo)
            if timeSinceVideo < 3.0 {
                // Si on reçoit de la vidéo, le drone EST connecté
                return true
            }
        }
        
        // Vérification 3 : Navdata reçues récemment (fallback)
        if let lastNav = lastValidNavdataTime {
            let timeSinceNav = Date().timeIntervalSince(lastNav)
            if timeSinceNav < 3.0 {
                return true
            }
        }
        
        // Aucune donnée récente
        return false
    }
    
    func setNetworkLogicalConnected(_ connected: Bool) {
        networkLogicalConnected = connected
    }
    
    // MARK: - Connection Management
    
    func connect() {
        print("🔌 Connecting to drone at \(DroneConfig.ip)...")
        
        cleanupConnections()
        
        isNetworkReady = false
        isReceivingNavData = false
        isReceivingValidNavdata = false
        lastNavDataTime = nil
        lastValidNavdataTime = nil
        lastVideoFrameTime = nil
        isConfigured = false
        failsafeState = .normal
        reconnectionAttempts = 0
        networkLogicalConnected = true
        
        setupNetworkConnections()
    }
    
    private func setupNetworkConnections() {
        let host = NWEndpoint.Host(DroneConfig.ip)
        let commandEndpoint = NWEndpoint.Port(rawValue: DroneConfig.atPort)!
        let navEndpoint = NWEndpoint.Port(rawValue: DroneConfig.navdataPort)!
        
        let udpParams = NWParameters.udp
        udpParams.requiredInterfaceType = .wifi
        udpParams.allowLocalEndpointReuse = true
        
        commandConnection = NWConnection(host: host, port: commandEndpoint, using: udpParams)
        
        commandConnection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("✅ Command connection ready")
                self?.isNetworkReady = true
                self?.initializeDrone()
            case .failed(let error):
                print("❌ Command connection failed: \(error)")
                self?.isNetworkReady = false
            case .waiting(let error):
                print("⏳ Command connection waiting: \(error)")
            default:
                break
            }
        }
        
        commandConnection?.start(queue: .main)
        
        navigationConnection = NWConnection(host: host, port: navEndpoint, using: udpParams)
        
        navigationConnection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("✅ Navigation connection ready")
                self?.startNavDataLoop()
            case .failed(let error):
                print("❌ Navigation connection failed: \(error)")
                self?.isReceivingNavData = false
                self?.isReceivingValidNavdata = false
            default:
                break
            }
        }
        
        navigationConnection?.start(queue: .main)
    }
    
    func disconnect() {
        print("🔌 Disconnecting from drone")
        
        if isConnectedToDrone() {
            sendCommand(atCommands.ref(ATCommands.ControlFlags.land))
            // Use async delay instead of blocking
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.cleanupConnections()
            }
        } else {
            cleanupConnections()
        }
        
        isNetworkReady = false
        isReceivingNavData = false
        isReceivingValidNavdata = false
        lastNavDataTime = nil
        lastValidNavdataTime = nil
        lastVideoFrameTime = nil
        isConfigured = false
        failsafeState = .normal
        reconnectionAttempts = 0
        networkLogicalConnected = false
        
        print("✅ Disconnected")
    }
    
    private func cleanupConnections() {
        commandTimer?.invalidate()
        commandTimer = nil
        failsafeTimer?.invalidate()
        failsafeTimer = nil
        reconnectionTimer?.invalidate()
        reconnectionTimer = nil
        rthTimer?.invalidate()
        rthTimer = nil
        hoverTimer?.invalidate()
        hoverTimer = nil
        
        commandConnection?.cancel()
        commandConnection = nil
        navigationConnection?.cancel()
        navigationConnection = nil
        
        videoHandler.stopStreaming()
    }
    
    // MARK: - Initialization
    
    private func initializeDrone() {
        print("⚙️ Initializing drone per SDK...")
        
        // Step 1: Send CONFIG_IDS (Session, User, Application IDs)
        // SDK Reference: Chapter 6.4.2 - Configuration must start with IDs
        sendCommand(atCommands.configIds(sessionId: sessionId, userId: userId, applicationId: applicationId))
        
        // Step 2: Send CTRL command with mode 5 (ACK for configuration)
        // This acknowledges we're ready to receive configuration
        sendCommand(atCommands.ctrl(mode: 5, miscValue: 0))
        
        // Step 3: Small delay for drone to process
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.configureDrone()
        }
    }
    
    private func configureDrone() {
        print("⚙️ Configuring drone per SDK...")
        
        // Step 1: Enable NavData options (disable demo-only mode)
        // SDK Reference: Chapter 6.6.1 - general:navdata_demo
        sendCommand(atCommands.config(key: "general:navdata_demo", value: "FALSE"))
        
        // Step 2: Video configuration
        sendCommand(atCommands.setVideoCodec(.h264_720p))
        sendCommand(atCommands.setVideoBitrate(2000000))
        sendCommand(atCommands.setFPS(30))
        
        // Step 3: Send CTRL command to acknowledge configuration
        sendCommand(atCommands.ctrl(mode: 4, miscValue: 0))
        
        isConfigured = true
        print("✅ Drone configured per SDK")
        
        // Start command and monitoring loops
        startCommandLoop()
        startFailsafeMonitoring()
        
        if HoverConfig.autoHoverEnabled {
            startHoverMonitoring()
        }
        
        // Start video stream
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.videoHandler.startStreaming()
        }
    }
    
    // MARK: - Command Loop
    
    private func startCommandLoop() {
        commandTimer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { [weak self] _ in
            self?.sendPeriodicCommands()
        }
    }
    
    private func sendPeriodicCommands() {
        sendCommand(atCommands.comwdg())
        
        if roll != 0 || pitch != 0 || yaw != 0 || gaz != 0 {
            sendCommand(atCommands.pcmd(enable: true, roll: roll, pitch: pitch, gaz: gaz, yaw: yaw))
        } else {
            sendCommand(atCommands.pcmd(enable: false, roll: 0, pitch: 0, gaz: 0, yaw: 0))
        }
    }
    
    // MARK: - Navigation Data Loop
    
    private func startNavDataLoop() {
        print("🔄 Starting navdata loop")
        
        // Envoyer la commande d'activation navdata
        sendCommand(atCommands.config(key: "general:navdata_demo", value: "FALSE"))
        
        // Démarrer la réception continue
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.startContinuousNavDataReception()
        }
    }

    private func startContinuousNavDataReception() {
        guard navigationConnection != nil else {
            print("⚠️ navigationConnection is nil")
            return
        }
        
        print("✅ Starting continuous navdata reception")
        
        // Envoyer le trigger pour activer les navdata
        sendNavDataTrigger()
        
        // Démarrer la boucle de réception
        receiveNextNavData()
        
        // Re-trigger toutes les 5 secondes (au cas où)
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.sendNavDataTrigger()
        }
    }
    
    private func sendNavDataTrigger() {
        guard let connection = navigationConnection else { return }
        
        // Envoyer "\x01\x00\x00\x00" pour activer les navdata
        let triggerData = Data([0x01, 0x00, 0x00, 0x00])
        
        connection.send(content: triggerData, completion: .contentProcessed { error in
            if let error = error {
                print("❌ Failed to send navdata trigger: \(error)")
            } else {
                print("✅ Navdata trigger sent")
            }
        })
    }

    private func receiveNextNavData() {
        guard let connection = navigationConnection else { return }
        
        connection.receiveMessage { [weak self] data, context, isComplete, error in
            guard let self = self else { return }
            
            if error != nil {
                // Erreur réseau - continuer quand même
                self.isReceivingNavData = false
                self.isReceivingValidNavdata = false
                
                // Réessayer après 100ms
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.receiveNextNavData()
                }
                return
            }
            
            if let data = data, data.count > 0 {
                
                // Validation simple
                if data.count >= 16 {
                    // Marquer comme valide
                    self.isReceivingValidNavdata = true
                    self.lastValidNavdataTime = Date()
                    
                    // Parser
                    if let navData = self.navDataParser.parse(data) {
                        self.currentNavData = navData
                        self.isReceivingNavData = true
                        self.lastNavDataTime = Date()
                        self.onNavDataReceived?(navData)
                        
                        // Auto-set home point
                        if self.homePoint == nil,
                           navData.gpsNumSatellites >= GPSConfig.minSatellites,
                           navData.gpsLatitude != 0,
                           navData.gpsLongitude != 0 {
                            
                            self.homePoint = (navData.gpsLatitude, navData.gpsLongitude)
                            self.homeAltitude = navData.altitudeMeters
                            print(String(format: "🏠 Auto-Home: %.6f, %.6f @ %.1fm",
                                         navData.gpsLatitude, navData.gpsLongitude, navData.altitudeMeters))
                            
                            self.onHomePointSet?(navData.gpsLatitude, navData.gpsLongitude)
                        }
                    } else {
                        print("❌ navDataParser.parse() returned nil")
                    }
                }
            }
            self.receiveNextNavData()
        }
    }
    
    private func receiveNavData() {
        guard let connection = navigationConnection else {
            print("⚠️ navigationConnection is nil")
            return
        }
        
        connection.receiveMessage { [weak self] data, context, isComplete, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ receiveMessage error: \(error)")
                self.isReceivingNavData = false
                self.isReceivingValidNavdata = false
                return
            }
            
            guard let data = data else {
                print("⚠️ receiveMessage returned nil data")
                self.isReceivingNavData = false
                self.isReceivingValidNavdata = false
                return
            }
            
            // Validation simple
            guard data.count >= 16 else {
                print("⚠️ Navdata too short: \(data.count) bytes")
                return
            }
            
            // ✅ Marquer comme valide
            self.isReceivingValidNavdata = true
            self.lastValidNavdataTime = Date()
            
            // ⬇️ PARSER
            if let navData = self.navDataParser.parse(data) {
                self.currentNavData = navData
                self.isReceivingNavData = true
                self.lastNavDataTime = Date()
                self.onNavDataReceived?(navData)
                
                // Auto-set home point
                if self.homePoint == nil,
                   navData.gpsNumSatellites >= GPSConfig.minSatellites,
                   navData.gpsLatitude != 0,
                   navData.gpsLongitude != 0 {
                    
                    self.homePoint = (navData.gpsLatitude, navData.gpsLongitude)
                    self.homeAltitude = navData.altitudeMeters
                    print(String(format: "🏠 Auto-Home: %.6f, %.6f @ %.1fm",
                                 navData.gpsLatitude, navData.gpsLongitude, navData.altitudeMeters))
                    
                    self.onHomePointSet?(navData.gpsLatitude, navData.gpsLongitude)
                }
            } else {
                print("❌ navDataParser.parse() returned nil")
            }
        }
    }
    
    // MARK: - Hover Management
    
    private func startHoverMonitoring() {
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkHoverState()
        }
    }
    
    private func checkHoverState() {
        guard let lastInput = lastInputTime else { return }
        
        let timeSinceInput = Date().timeIntervalSince(lastInput)
        
        if timeSinceInput >= HoverConfig.inputTimeout && !isAutoHoverActive {
            activateAutoHover()
        }
    }
    
    private func activateAutoHover() {
        guard currentNavData?.isFlying == true else { return }
        
        isAutoHoverActive = true
        setMovement(roll: 0, pitch: 0, yaw: 0, gaz: 0)
        print("🛸 Auto-hover activated (no input for \(HoverConfig.inputTimeout)s)")
    }
    
    private func deactivateAutoHover() {
        if isAutoHoverActive {
            isAutoHoverActive = false
            print("🎮 Manual control resumed")
        }
    }
    
    // MARK: - Failsafe System
    // SDK Reference: Chapter 6.7 - Watchdog and Emergency Procedures
    
    private func startFailsafeMonitoring() {
        failsafeTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkConnectionHealth()
        }
    }

    private func checkConnectionHealth() {
        let droneConnected = isConnectedToDrone()
        
        // If drone reconnected during failsafe, recover
        if droneConnected && failsafeState != .normal {
            recoverFromFailsafe()
            return
        }
        
        // If drone disconnected and in normal mode, activate failsafe
        // SDK: Watchdog timeout causes emergency mode if no COMWDG received
        if !droneConnected && failsafeState == .normal {
            // Wait 5 seconds before activating (avoid false positives at startup)
            // SDK recommends 2-5 second threshold for connection loss detection
            if let startTime = lastValidNavdataTime ?? lastVideoFrameTime,
               Date().timeIntervalSince(startTime) > 5.0 {
                activateFailsafe()
            }
            return
        }
        
        // If in reconnection mode and timeout reached
        // SDK: After multiple reconnection failures, initiate emergency landing
        if failsafeState == .reconnecting,
           let startTime = failsafeStartTime,
           Date().timeIntervalSince(startTime) >= failsafeTimeout,
           reconnectionAttempts >= maxReconnectionAttempts {
            handleFailsafeTimeout()
        }
    }
    
    private func activateFailsafe() {
        print("🚨 FAILSAFE ACTIVATED - Wi-Fi Connection Lost")
        print("   SDK Compliance: Initiating reconnection attempts per Chapter 6.7")
        failsafeState = .reconnecting
        failsafeStartTime = Date()
        reconnectionAttempts = 0
        
        // Stop movement commands per SDK failsafe procedure
        setMovement(roll: 0, pitch: 0, yaw: 0, gaz: 0)
        
        // Visual feedback via LED animation
        performLEDAnimation(.blinkOrange, frequency: 3.0, duration: 60)
        
        onFailsafeActivated?("Perte connexion Wi-Fi drone")
        onConnectionLost?()
        
        startReconnectionAttempts()
    }
    
    private func startReconnectionAttempts() {
        print("🔄 Starting reconnection loop")
        
        reconnectionTimer?.invalidate()
        
        reconnectionTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            self.reconnectionAttempts += 1
            print("🔄 Reconnection attempt \(self.reconnectionAttempts)/\(self.maxReconnectionAttempts)")
            
            self.attemptFullReconnection()
            
            if self.reconnectionAttempts >= self.maxReconnectionAttempts {
                self.reconnectionTimer?.invalidate()
                self.reconnectionTimer = nil
            }
        }
        
        attemptFullReconnection()
    }
    
    private func attemptFullReconnection() {
        print("🔌 Full reconnection starting...")
        cleanupConnections()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.setupNetworkConnections()
        }
    }
    
    private func recoverFromFailsafe() {
        guard failsafeState != .normal else { return }
        
        print("✅ Drone connection recovered")
        
        reconnectionTimer?.invalidate()
        reconnectionTimer = nil
        rthTimer?.invalidate()
        rthTimer = nil
        
        failsafeState = .normal
        failsafeStartTime = nil
        reconnectionAttempts = 0
        
        performLEDAnimation(.blinkGreen, frequency: 1.0, duration: 3)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            if self?.isConnectedToDrone() == true {
                self?.onFailsafeRecovered?()
            }
        }
    }
    
    private func handleFailsafeTimeout() {
        print("⏱️ Failsafe timeout")
        
        reconnectionTimer?.invalidate()
        reconnectionTimer = nil
        
        if homePoint != nil {
            failsafeState = .returningToHome
            performLEDAnimation(.blinkGreen, frequency: 2.0, duration: 120)
            print("🏠 Initiating Return To Home")
            onFailsafeActivated?("Retour au point Home")
            
            startAutomaticRTH()
            
        } else {
            print("❌ No home point - Landing")
            initiateFailsafeLanding()
        }
    }
    
    private func startAutomaticRTH() {
        var rthAttempts = 0
        let maxRthAttempts = 120
        
        rthTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if self.failsafeState != .returningToHome {
                timer.invalidate()
                return
            }
            
            let shouldContinue = self.executeRTHStep()
            
            if !shouldContinue {
                timer.invalidate()
                self.initiateFailsafeLanding()
                return
            }
            
            rthAttempts += 1
            if rthAttempts >= maxRthAttempts {
                print("⏱️ RTH timeout")
                timer.invalidate()
                self.initiateFailsafeLanding()
            }
        }
    }
    
    private func executeRTHStep() -> Bool {
        guard let home = homePoint, let current = currentNavData else {
            print("❌ RTH failed: No data")
            return false
        }
        
        let distance = calculateDistance(from: (current.gpsLatitude, current.gpsLongitude), to: home)
        
        if distance < arrivalTolerance {
            print("🏠 Arrived at home (\(String(format: "%.1f", distance))m)")
            return false
        }
        
        let bearing = calculateBearing(from: (current.gpsLatitude, current.gpsLongitude), to: home)
        
        let currentHeading = Double((current.yaw + 360).truncatingRemainder(dividingBy: 360))
        var relativeAngle = bearing - currentHeading
        
        if relativeAngle > 180 {
            relativeAngle -= 360
        } else if relativeAngle < -180 {
            relativeAngle += 360
        }
        
        let yawSpeed = Float(max(-0.5, min(0.5, relativeAngle / 90.0)))
        let forwardSpeed: Float = abs(relativeAngle) < 30 ? 0.25 : 0.0
        
        print(String(format: "🧭 RTH: %.0fm | Heading %.0f° → %.0f° (Δ%.0f°)",
                     distance, currentHeading, bearing, relativeAngle))
        
        setMovement(roll: 0, pitch: forwardSpeed, yaw: yawSpeed, gaz: 0)
        
        return true
    }
    
    private func initiateFailsafeLanding() {
        print("🛬 Failsafe Landing")
        failsafeState = .landing
        performLEDAnimation(.blinkRed, frequency: 4.0, duration: 30)
        onFailsafeActivated?("Atterrissage d'urgence")
        
        rthTimer?.invalidate()
        rthTimer = nil
        
        land()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            self?.failsafeState = .normal
            self?.failsafeStartTime = nil
            self?.reconnectionAttempts = 0
        }
    }
    
    // MARK: - Control Commands
    
    func takeoff() {
        print("🚁 Takeoff")
        sendCommand(atCommands.ref(ATCommands.ControlFlags.takeoff))
    }
    
    func land() {
        print("🛬 Landing")
        sendCommand(atCommands.ref(ATCommands.ControlFlags.land))
    }
    
    func emergency() {
        print("🚨 Emergency!")
        sendCommand(atCommands.ref(ATCommands.ControlFlags.emergency))
    }
    
    func resetEmergency() {
        print("🔄 Reset emergency")
        sendCommand(atCommands.ref(ATCommands.ControlFlags.land))
    }
    
    func hover() {
        print("🛸 Hover")
        setMovement(roll: 0, pitch: 0, yaw: 0, gaz: 0)
    }
    
    func flatTrim() {
        print("⚖️ Flat trim")
        sendCommand(atCommands.ftrim())
    }
    
    func calibrateMagnetometer() {
        print("🧭 Calibrating magnetometer")
        sendCommand(atCommands.calib(deviceNumber: 0))
    }
    
    func setMovement(roll: Float, pitch: Float, yaw: Float, gaz: Float) {
        self.roll = clamp(roll, min: -1.0, max: 1.0)
        self.pitch = clamp(pitch, min: -1.0, max: 1.0)
        self.yaw = clamp(yaw, min: -1.0, max: 1.0)
        self.gaz = clamp(gaz, min: -1.0, max: 1.0)
        
        if abs(roll) > 0.01 || abs(pitch) > 0.01 || abs(yaw) > 0.01 || abs(gaz) > 0.01 {
            lastInputTime = Date()
            deactivateAutoHover()
        }
    }
    
    // MARK: - Sensitivity Management
    
    /// Configure drone sensitivity via AT*CONFIG commands (SDK-compliant)
    /// - Parameter sensitivityPercent: Sensitivity from 10% to 100%
    
    // MARK: - Animation Commands
    
    func performLEDAnimation(_ animation: ATCommands.LEDAnimation, frequency: Float = 2.0, duration: Int = 3) {
        sendCommand(atCommands.led(animation: animation, frequency: frequency, duration: duration))
    }
    
    func performFlightAnimation(_ animation: ATCommands.FlightAnimation, duration: Int = 1000) {
        sendCommand(atCommands.anim(animation: animation, duration: duration))
    }
    
    // MARK: - Video Commands
    
    func startVideoRecording() {
        videoHandler.startRecording()
    }
    
    func stopVideoRecording() {
        videoHandler.stopRecording()
    }
    
    func capturePhoto() -> Bool {
        guard currentNavData != nil else { return false }
        print("📸 Photo capture")
        return true
    }
    
    func switchVideoChannel(_ channel: ATCommands.VideoChannel) {
        sendCommand(atCommands.setVideoChannel(channel))
    }
        
        guard let home = homePoint else { return }
        
        let distance = calculateDistance(from: (current.gpsLatitude, current.gpsLongitude), to: home)
        
        print(String(format: "🏠 Manual RTH: %.0fm", distance))
        
        failsafeState = .returningToHome
        performLEDAnimation(.blinkGreen, frequency: 2.0, duration: 120)
        onFailsafeActivated?("Retour Home (manuel)")
        
        startAutomaticRTH()
    }
    
    func clearHomePoint() {
        homePoint = nil
        print("🏠 Home cleared")
    }
    
    // MARK: - GPS Calculations
    
    private func calculateDistance(from: (latitude: Double, longitude: Double),
                                 to: (latitude: Double, longitude: Double)) -> Double {
        let earthRadius = 6371000.0
        
        let lat1Rad = from.latitude * .pi / 180
        let lat2Rad = to.latitude * .pi / 180
        let deltaLatRad = (to.latitude - from.latitude) * .pi / 180
        let deltaLonRad = (to.longitude - from.longitude) * .pi / 180
        
        let a = sin(deltaLatRad/2) * sin(deltaLatRad/2) +
                cos(lat1Rad) * cos(lat2Rad) *
                sin(deltaLonRad/2) * sin(deltaLonRad/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        
        return earthRadius * c
    }
    
    private func calculateBearing(from: (latitude: Double, longitude: Double),
                                to: (latitude: Double, longitude: Double)) -> Double {
        let lat1Rad = from.latitude * .pi / 180
        let lat2Rad = to.latitude * .pi / 180
        let deltaLonRad = (to.longitude - from.longitude) * .pi / 180
        
        let y = sin(deltaLonRad) * cos(lat2Rad)
        let x = cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(deltaLonRad)
        
        let bearingRad = atan2(y, x)
        let bearingDeg = bearingRad * 180 / .pi
        
        return (bearingDeg + 360).truncatingRemainder(dividingBy: 360)
    }
    
    // MARK: - Configuration
    
    func setMaxAltitude(_ meters: Int) {
        sendCommand(atCommands.setMaxAltitude(meters * 1000))
    }
    
    func setMaxTilt(_ degrees: Float) {
        sendCommand(atCommands.setMaxTilt(Int(degrees * 1000)))
    }
    
    func setHullProtection(_ enabled: Bool) {
        sendCommand(atCommands.setHullProtection(enabled))
    }
    
    // MARK: - Helper Functions
    
    private func sendCommand(_ command: String) {
        guard let connection = commandConnection else { return }
        
        let data = Data(command.utf8)
        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error, self.failsafeState == .normal {
                print("❌ Send error: \(error)")
            }
        })
    }
    
    private func clamp(_ value: Float, min: Float, max: Float) -> Float {
        return Swift.min(Swift.max(value, min), max)
    }
    
    // MARK: - Status
    
    func getConnectionStatus() -> String {
        return isConnectedToDrone() ? "Connected" : "Disconnected"
    }
    
    func getFailsafeState() -> String {
        switch failsafeState {
        case .normal:
            return isConnectedToDrone() ? "Connecté" : "Déconnecté"
        case .reconnecting:
            return "Reconnexion (\(reconnectionAttempts)/\(maxReconnectionAttempts))"
        case .returningToHome:
            if let home = homePoint, let current = currentNavData {
                let distance = calculateDistance(from: (current.gpsLatitude, current.gpsLongitude), to: home)
                return String(format: "RTH (%.0fm)", distance)
            }
            return "Retour Home"
        case .landing:
            return "Atterrissage"
        }
    }
    
    func getCurrentControlState() -> String {
        guard let navData = currentNavData else { return "Idle" }
        
        if navData.isFlying {
            return "Flying"
        } else if navData.isEmergency {
            return "Emergency"
        } else {
            return "Landed"
        }
    }
    
    func getBatteryLevel() -> Int {
        return currentNavData?.batteryPercentage ?? 0
    }
    
    func isFlying() -> Bool {
        return currentNavData?.isFlying ?? false
    }
    
    func getGPSData() -> (lat: Double, lon: Double, sats: Int)? {
        guard let navData = currentNavData else { return nil }
        return (navData.gpsLatitude, navData.gpsLongitude, navData.gpsNumSatellites)
    }
}
