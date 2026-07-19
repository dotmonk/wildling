import Foundation
import Wildling

@main
enum WildlingMain {
    static func main() {
        exit(Cli.run(argv: Array(CommandLine.arguments.dropFirst())))
    }
}
