#!/usr/bin/env bash
# Runs inside the emulator job: UI test on the debug build, then cold-start timing of the release build.
set -u
D=app/build/outputs/apk
adb install -r -t $D/debug/app-debug.apk >/dev/null
adb install -r -t $D/androidTest/debug/app-debug-androidTest.apk >/dev/null
adb shell pm grant app.mossling android.permission.POST_NOTIFICATIONS 2>/dev/null || true
out=$(adb shell am instrument -w -r app.mossling.test/androidx.test.runner.AndroidJUnitRunner 2>&1)
if echo "$out" | grep -q "OK ("; then
  echo "::notice title=Native UI test::critical paths passed"
else
  msg=$(echo "$out" | grep -E "Error|Exception|expected|at app.mossling|INSTRUMENTATION_STATUS: stack" | head -25 | sed ':a;N;$!ba;s/%/%25/g;s/\r//g;s/\n/%0A/g')
  echo "::error title=Native UI test::${msg}"
  fail=1
fi
adb uninstall app.mossling >/dev/null
adb install -r $D/release/app-release.apk >/dev/null
# first launch lets ProfileInstaller write the profile; then compile with it, as the Play Store would
adb shell am start -W -n app.mossling/.MainActivity >/dev/null; sleep 6
adb shell cmd package compile -m speed-profile -f app.mossling >/dev/null
t=""
for i in 1 2 3 4 5; do
  adb shell am force-stop app.mossling; sleep 1
  v=$(adb shell am start -W -n app.mossling/.MainActivity | tr -d '\r' | awk -F': ' '/TotalTime/{print $2}')
  t="$t $v"; sleep 2
done
med=$(echo $t | tr ' ' '\n' | sort -n | sed -n 3p)
echo "::notice title=Native cold start::median ${med} ms (runs:${t}) on the CI emulator — software GPU, slower than a phone"
exit ${fail:-0}
