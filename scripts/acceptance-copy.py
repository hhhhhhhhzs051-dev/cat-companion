"""Exercise exact migration/validation method bodies in an isolated directory.

Only Bundle URL dependencies are injected. This is not a new-account install test.
"""
from pathlib import Path
import subprocess
import tempfile

source = Path('src/macos/main.swift').read_text()
methods = source[source.index('    func ensureCopy()'):source.index('    func showError(')]
methods = methods.replace('Bundle.main.bundleURL.deletingLastPathComponent()', 'adjacentDirectory')
with tempfile.TemporaryDirectory(prefix='cat-copy-acceptance-') as folder:
    root = Path(folder)
    program = '''import Foundation
final class Probe {
 var selfTest=false, isPlayPreview=false
 let copyURL:URL, resources:URL, adjacentDirectory:URL
 init(_ root:URL) {
  copyURL=root.appendingPathComponent("user/猫咪文案.json")
  resources=root.appendingPathComponent("resources")
  adjacentDirectory=root.appendingPathComponent("adjacent")
 }
''' + methods + '''
}
let root=URL(fileURLWithPath:CommandLine.arguments[1])
let probe=Probe(root)
let fm=FileManager.default
for dir in [probe.resources,probe.adjacentDirectory] {try fm.createDirectory(at:dir,withIntermediateDirectories:true)}
func data(_ text:String)->Data {try! JSONSerialization.data(withJSONObject:["study":[text],"pet":[text]])}
let builtin=data("内置"),legacy=data("旧文案"),custom=data("用户修改")
try builtin.write(to:probe.resources.appendingPathComponent("cat-copy.json"))
try probe.ensureCopy()
precondition(try Data(contentsOf:probe.copyURL)==builtin)
try fm.removeItem(at:probe.copyURL)
let adjacent=probe.adjacentDirectory.appendingPathComponent("猫咪文案.json")
try legacy.write(to:adjacent)
try probe.ensureCopy()
precondition(try Data(contentsOf:probe.copyURL)==legacy)
precondition(try Data(contentsOf:adjacent)==legacy)
try custom.write(to:probe.copyURL)
try probe.ensureCopy()
precondition(try Data(contentsOf:probe.copyURL)==custom)
try fm.removeItem(at:probe.copyURL)
try Data("invalid".utf8).write(to:adjacent)
do {try probe.ensureCopy();fatalError("Invalid legacy accepted")} catch {}
precondition(!fm.fileExists(atPath:probe.copyURL.path))
probe.selfTest=true
try probe.ensureCopy()
precondition(!fm.fileExists(atPath:probe.copyURL.path))
probe.selfTest=false;probe.isPlayPreview=true
try probe.ensureCopy()
precondition(!fm.fileExists(atPath:probe.copyURL.path))
print("PASS isolated exact-method migration: builtin fallback, legacy copy, legacy retained, user edits preserved, invalid data fail closed, self-test and preview writes suppressed")
'''
    # Swift precondition autoclosures cannot throw.
    program = program.replace('precondition(try Data(contentsOf:', 'precondition((try! Data(contentsOf:')
    for name in ['probe.copyURL', 'adjacent']:
        program = program.replace(f'{name})==', f'{name}))==')
    swift = root / 'probe.swift'
    swift.write_text(program)
    subprocess.run(['swift', str(swift), str(root)], check=True)
