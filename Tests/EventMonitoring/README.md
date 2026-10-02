# Event monitoring regressions

Build dependencies, then run the standalone regression executable under both sanitizers:

```sh
./script/build_and_run.sh --verify
./script/test_event_monitoring.sh thread
./script/test_event_monitoring.sh address
```

The runner compiles the production shortcut cache and event-monitor sources directly. It links the Debug build's Defaults and Scribe dependencies and uses a minimal WindowAction fixture. The rest of the app and the prebuilt dependencies are not sanitizer-instrumented by this runner.

Coverage:

- Ensure cycles do not gain implicit Shift shortcuts.
- Publish internally consistent shortcut-cache snapshots while settings change.
- Classify tap notifications using the callback type even when the event payload has a different type.
- Prevent a queued timeout restart from reviving a stopped monitor.
- Release monitors without explicitly stopping them, then drain deferred callback-context cleanup.

The tests use a temporary preferences suite and post no keyboard/mouse events. Live event-tap tests run only when Input Monitoring access is already available; otherwise they report SKIP. A 30-second watchdog fails hung tests. Temporary executables are deleted on exit.

## Crash report interpretation

The supplied build 1760 report detected free-block heap corruption on EventTapThread while allocating a Set in isFnSpecialKey. This identifies the detection site, not necessarily the original corrupting access; see [Apple's memory-access crash guidance](https://developer.apple.com/documentation/xcode/investigating-memory-access-crashes).

Code review identified unsynchronized timer/action and cache access, a raw monitor pointer used by callbacks during teardown, and asynchronous teardown capturing self even from deinit. Regression testing also reproduced dropped RunLoop blocks: CFRunLoopPerformBlock requires CFRunLoopMode.commonModes.rawValue (a CFString), while casting the Swift mode wrapper to CFTypeRef produces a different runtime type.

These defects are addressed, but neither sanitizer run reproduces a full overnight idle or sleep/wake cycle. To verify the reported scenario, run the fixed app with the original trigger settings, leave it idle overnight, and exercise the first shortcut after waking/unlocking. Check both activation and release with left and right trigger modifiers. Retain any new crash report; do not treat a successful short stress test as proof that this exact crash is eliminated.
