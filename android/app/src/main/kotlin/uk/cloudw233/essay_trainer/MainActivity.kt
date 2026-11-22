package uk.cloudw233.essay_trainer

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val shareChannel = "essay_trainer/share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, shareChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "shareText") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val text = call.argument<String>("text")
                if (text.isNullOrBlank()) {
                    result.error("invalid_text", "Report text is empty", null)
                    return@setMethodCallHandler
                }

                val subject = call.argument<String>("subject")
                val sendIntent = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_TEXT, text)
                    subject?.trim()?.takeIf { it.isNotEmpty() }?.let {
                        putExtra(Intent.EXTRA_SUBJECT, it)
                    }
                }

                startActivity(Intent.createChooser(sendIntent, "分享批改报告"))
                result.success(true)
            }
    }
}
