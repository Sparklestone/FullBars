import Foundation

/// Centralized accessibility identifiers for UI testing and VoiceOver.
///
/// Usage in views:   `.accessibilityIdentifier(AccessibilityID.Results.roomList)`
/// Usage in tests:   `app.tables[AccessibilityID.Results.roomList]`
///
/// Keeping identifiers in one place prevents typo-driven test failures
/// and makes it easy to audit VoiceOver coverage.
enum AccessibilityID {

    // MARK: - Onboarding

    enum Onboarding {
        static let nextButton        = "onboarding.next"
        static let backButton        = "onboarding.back"
        static let skipButton        = "onboarding.skip"
        static let dwellingTypePicker = "onboarding.dwellingType"
        static let squareFootageField = "onboarding.squareFootage"
        static let floorStepper      = "onboarding.floors"
        static let peopleStepper     = "onboarding.people"
        static let meshToggle        = "onboarding.hasMesh"
        static let ispNameField      = "onboarding.ispName"
        static let ispSpeedField     = "onboarding.ispSpeed"
    }

    // MARK: - Dashboard

    enum Dashboard {
        static let gradeCard         = "dashboard.gradeCard"
        static let scanButton        = "dashboard.scanButton"
        static let speedTestButton   = "dashboard.speedTest"
        static let diagnosticsButton = "dashboard.diagnostics"
    }

    // MARK: - Results

    enum Results {
        static let roomList          = "results.roomList"
        static let shareBadgeButton  = "results.shareBadge"
        static let roomRow           = "results.roomRow"       // append room name
        static let gradeLabel        = "results.gradeLabel"
        static let ispComparisonCard = "results.ispComparison"
    }

    // MARK: - Room Detail

    enum RoomDetail {
        static let gradeRing         = "roomDetail.gradeRing"
        static let floorPlanTab      = "roomDetail.floorPlan"
        static let layersTab         = "roomDetail.layers"
        static let recommendationsTab = "roomDetail.recommendations"
        static let heatmapToggle     = "roomDetail.heatmapToggle"
        static let deadZoneToggle    = "roomDetail.deadZoneToggle"
        static let devicesToggle     = "roomDetail.devicesToggle"
    }

    // MARK: - Speed Test

    enum SpeedTest {
        static let startButton       = "speedTest.start"
        static let stopButton        = "speedTest.stop"
        static let shareButton       = "speedTest.share"
        static let tabPicker         = "speedTest.tabPicker"
        static let downloadLabel     = "speedTest.download"
        static let uploadLabel       = "speedTest.upload"
        static let latencyLabel      = "speedTest.latency"
    }

    // MARK: - Heatmap / Scan

    enum Scan {
        static let recordButton      = "scan.record"
        static let stopButton        = "scan.stop"
        static let modePicker        = "scan.modePicker"
        static let statsCard         = "scan.statsCard"
    }

    // MARK: - Settings

    enum Settings {
        static let upgradeButton     = "settings.upgrade"
        static let editHomeButton    = "settings.editHome"
        static let editISPButton     = "settings.editISP"
        static let dataSharingToggle = "settings.dataSharing"
        static let resetOnboarding   = "settings.resetOnboarding"
        static let addHomeButton     = "settings.addHome"
        static let darkModeToggle    = "settings.darkMode"
        static let measurementUnit   = "settings.measurementUnit"
    }

    // MARK: - BLE Scanner

    enum BLE {
        static let deviceList        = "ble.deviceList"
        static let scanButton        = "ble.scan"
        static let deviceRow         = "ble.deviceRow"   // append device name
    }

    // MARK: - Coverage Planner

    enum Planner {
        static let deadZoneList      = "planner.deadZones"
        static let meshRecommendation = "planner.meshRec"
        static let coveragePercentage = "planner.coveragePct"
    }
}
