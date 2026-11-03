import Testing
@testable import AgentScheduler

struct ShellTests {
    @Test(arguments: ["", "centralos", "two words", "Client's Work", "''", "$HOME `pwd` $(pwd)", "back\\slash", "line\nbreak", "*", "-n", "a; print injected", "Café ☕️"])
    func quotedTextReachesZshUnchanged(_ text: String) {
        #expect(Shell.run("/bin/zsh", ["-f", "-c", "print -rn -- \(Shell.quote(text))"]).output == text)
    }

    @Test func runReportsStatusAndOutputFromTheFolder() {
        let result = Shell.run("/bin/zsh", ["-f", "-c", "pwd; print -u2 warning; exit 3"], in: "/usr/bin")
        #expect(result.status == 3)
        #expect(result.output == "/usr/bin\nwarning\n")
    }

    @Test func runReadsOutputLargerThanThePipeBuffer() {
        #expect(Shell.run("/bin/zsh", ["-f", "-c", "head -c 300000 /dev/zero | tr '\\0' x"]).output.count == 300_000)
    }
}
