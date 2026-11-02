#!/bin/bash
# Build operations are shared by the user commands and CI. Source common.sh first.
build_model_tests() {
    require_swift
    xcrun swiftc -swift-version 5 -parse-as-library -framework IOKit \
        "$PROJECT_ROOT/Sources/Support/WallpaperIdentity.swift" "$PROJECT_ROOT/Tools/LockScreenModel.swift" "$PROJECT_ROOT/Tools/MovieFormat.swift" "$PROJECT_ROOT/Sources/Support/PlaybackState.swift" "$PROJECT_ROOT/Sources/Support/LockDisplayController.swift" "$PROJECT_ROOT/Tests/LockScreenFixtures.swift" \
        -o "$BUILD_DIR/lockscreen-model-tests"
    "$BUILD_DIR/lockscreen-model-tests"
}

build_lock_tool() {
    require_swift
    xcrun swiftc -swift-version 5 -parse-as-library -target "$(uname -m)-apple-macosx13.0" \
        -framework AppKit -framework AVFoundation -framework VideoToolbox \
        "$PROJECT_ROOT/Sources/Support/WallpaperIdentity.swift" "$PROJECT_ROOT/Sources/Support/NativePlaybackSettings.swift" "$PROJECT_ROOT/Tools/LockScreenModel.swift" "$PROJECT_ROOT/Tools/MovieFormat.swift" "$PROJECT_ROOT/Tools/VideoPreparation.swift" \
        "$PROJECT_ROOT/Sources/Support/DesktopBackdrop.swift" \
        "$PROJECT_ROOT/Tools/LockScreenSetup.swift" -o "$BUILD_DIR/lockscreen-tool"
}

build_app() {
    require_swift
    # Build resources from scratch so deleted local media/config cannot linger.
    rm -rf "$APP"
    mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
    xcrun swiftc -swift-version 5 -O -whole-module-optimization \
        -target "$(uname -m)-apple-macosx13.0" \
        -framework AppKit -framework AVFoundation -framework QuartzCore \
        -framework UniformTypeIdentifiers -framework IOKit \
        "$PROJECT_ROOT/Sources/main.swift" "$PROJECT_ROOT"/Sources/{App,Playback,UI,Support,LockScreen}/*.swift \
        -o "$APP/Contents/MacOS/$APP_EXECUTABLE"
    cp "$PROJECT_ROOT/Info.plist" "$APP/Contents/Info.plist"
    if [[ -s "$PROJECT_ROOT/Videos/wallpaper.mp4" ]]; then
        cp "$PROJECT_ROOT/Videos/wallpaper.mp4" "$APP/Contents/Resources/"
    fi
    # Lock Screen integration is optional on older macOS releases.
    if [[ "$(sw_vers -productVersion | cut -d. -f1)" -ge 26 ]]; then
        build_lock_tool
        cp "$BUILD_DIR/lockscreen-tool" "$APP/Contents/Resources/"
        build_native_extension
    fi
    cp "$PROJECT_ROOT/LICENSE" "$PROJECT_ROOT/THIRD_PARTY_NOTICES.md" "$APP/Contents/Resources/"
    if [[ -f "$PROJECT_ROOT/MEDIA_LICENSE.md" ]]; then cp "$PROJECT_ROOT/MEDIA_LICENSE.md" "$APP/Contents/Resources/"; fi
    /usr/bin/ditto "$PROJECT_ROOT/LICENSES" "$APP/Contents/Resources/LICENSES"
    # Finder may attach metadata to .app folders in extracted/synced checkouts.
    # Strip only signing-incompatible metadata from our generated bundle.
    /usr/bin/xattr -dr com.apple.FinderInfo "$APP" 2>/dev/null || true
    /usr/bin/xattr -dr com.apple.ResourceFork "$APP" 2>/dev/null || true
    /usr/bin/codesign --force --deep --sign - "$APP"
    echo "Built: $APP"
}

build_native_extension() {
    local extension="$APP/Contents/Extensions/NightCockpitNative.appex"
    mkdir -p "$extension/Contents/MacOS"
    xcrun swiftc -swift-version 5 -O -parse-as-library -application-extension \
        -Xlinker -e -Xlinker _NSExtensionMain -Xlinker -u -Xlinker _main \
        -target "$(uname -m)-apple-macosx26.0" \
        -framework AppKit -framework AVFoundation -framework QuartzCore -framework ExtensionFoundation \
        -import-objc-header "$PROJECT_ROOT/NativeExtension/NativeBridge.h" \
        "$PROJECT_ROOT/Sources/Support/NativePlaybackSettings.swift" "$PROJECT_ROOT"/NativeExtension/*.swift \
        -o "$extension/Contents/MacOS/NightCockpitNative"
    cp "$PROJECT_ROOT/NativeExtension/Info.plist" "$extension/Contents/Info.plist"
    /usr/bin/xattr -dr com.apple.FinderInfo "$extension" 2>/dev/null || true
    /usr/bin/xattr -dr com.apple.ResourceFork "$extension" 2>/dev/null || true
    /usr/bin/codesign --force --sign - --entitlements "$PROJECT_ROOT/NativeExtension/Entitlements.plist" "$extension"
}
