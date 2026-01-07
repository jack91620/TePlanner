#!/bin/bash
# TePlanner Android build and run script

ADB="/mnt/c/Users/dongxinbo/AppData/Local/Android/Sdk/platform-tools/adb.exe"
CMD="/mnt/c/Windows/System32/cmd.exe"

case "$1" in
    build)
        echo "Building..."
        $CMD /c "cd /d E:\\TePlanner\\android && gradlew.bat assembleDebug"
        ;;
    install)
        echo "Installing..."
        $CMD /c "cd /d E:\\TePlanner\\android && gradlew.bat installDebug"
        ;;
    run)
        echo "Running..."
        $ADB shell am start -n com.teplanner/.MainActivity
        ;;
    stop)
        echo "Stopping..."
        $ADB shell am force-stop com.teplanner
        ;;
    log)
        echo "Showing logs..."
        $ADB logcat -s "AndroidRuntime:E" "com.teplanner:*"
        ;;
    logall)
        echo "Showing all logs..."
        $ADB logcat | grep -E "teplanner|AndroidRuntime"
        ;;
    devices)
        $ADB devices
        ;;
    *)
        echo "Usage: ./run.sh [build|install|run|stop|log|logall|devices]"
        echo ""
        echo "Commands:"
        echo "  build   - Build debug APK"
        echo "  install - Build and install to device"
        echo "  run     - Launch the app"
        echo "  stop    - Force stop the app"
        echo "  log     - Show error logs"
        echo "  logall  - Show all app logs"
        echo "  devices - List connected devices"
        echo ""
        echo "Quick start: ./run.sh install && ./run.sh run"
        ;;
esac
