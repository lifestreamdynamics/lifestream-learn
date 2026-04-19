package com.lifestream.learn.lifestream_learn_app

import android.app.Activity
import android.view.WindowManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Platform bridge for Android's WindowManager.LayoutParams.FLAG_SECURE.
 * FLAG_SECURE blocks the window from being captured by screenshot
 * APIs, screen-recording, and Recents previews — critical for cue
 * overlays (would leak quiz answers) and admin screens (PII).
 *
 * Dart side: `app/lib/core/platform/flag_secure.dart`. Method channel
 * name matches: `com.lifestream.learn/flag_secure`.
 *
 * Method calls are idempotent — enabling twice is the same as once.
 * Always issue a `disable` in `dispose()` of the widget that enabled it;
 * a flag left set silently prevents screenshots on subsequent screens
 * that shouldn't be protected.
 */
class FlagSecureBridge(private val activity: Activity) {
    companion object {
        const val CHANNEL = "com.lifestream.learn/flag_secure"
    }

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enable" -> {
                        activity.runOnUiThread {
                            activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }
                    "disable" -> {
                        activity.runOnUiThread {
                            activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
