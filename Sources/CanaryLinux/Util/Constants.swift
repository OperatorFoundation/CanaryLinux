import Foundation
import Logging

let serverIPKey = "ServerIP"
let configPathKey = "ConfigPath"

var uiLog = Logger(label: "org.OperatorFoundation.CanaryDesktopUI", factory: CanaryLogHandler.init)
var globalRunningLog = RunningLog()

class RunningLog
{
    var logString: String = ""
}
