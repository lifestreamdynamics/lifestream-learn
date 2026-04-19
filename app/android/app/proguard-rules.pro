# Slice F: ProGuard/R8 rules for release builds.
#
# The Flutter Gradle plugin adds its own keep rules for io.flutter.*
# automatically, so this file only needs project-specific rules. Today
# we keep the FlagSecureBridge method-channel entry points so R8 doesn't
# rename the companion-object CHANNEL constant or the register method
# signature (the Dart side resolves these by string name).
-keep class com.lifestream.learn.lifestream_learn_app.FlagSecureBridge {
    public *;
}
-keep class com.lifestream.learn.lifestream_learn_app.MainActivity {
    public *;
}

# `dart run flutter_native_splash` generates resources that R8 might
# consider unreachable; keep the drawable ids around so Android 12+
# splash references resolve.
-keep class io.flutter.embedding.android.FlutterActivity { *; }
