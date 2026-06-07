import Foundation
import HarnessCore

@main
struct HarnessMCPServer {
    static func main() async {
        let server = MCPServer()
        await server.run()
    }
}
