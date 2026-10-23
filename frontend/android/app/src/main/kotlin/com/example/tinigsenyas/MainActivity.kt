package com.example.tinigsenyas

import android.content.Intent
import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "tinigsenyas/tts"
        ).setMethodCallHandler { call, result ->
            if (call.method == "installVoiceData") {
                try {
                    startActivity(Intent(TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA))
                    result.success(null)
                } catch (_: android.content.ActivityNotFoundException) {
                    result.error(
                        "VOICE_DATA_INSTALL_UNAVAILABLE",
                        "No Android text-to-speech voice-data installer is available.",
                        null
                    )
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
