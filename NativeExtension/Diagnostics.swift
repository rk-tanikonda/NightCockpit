import os

private let logger = Logger(subsystem: "org.nightcockpit.native", category: "runtime")
func debugLog(_ text: String) { logger.notice("\(text, privacy: .public)") }
