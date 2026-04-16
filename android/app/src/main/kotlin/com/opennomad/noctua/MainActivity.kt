package com.opennomad.noctua

import android.media.RingtoneManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  override fun configureFlutterEngine(engine: FlutterEngine) {
    super.configureFlutterEngine(engine)

    MethodChannel(engine.dartExecutor.binaryMessenger, "noctua/ringtones")
      .setMethodCallHandler { call, result ->
        if (call.method != "list") { result.notImplemented(); return@setMethodCallHandler }

        val type_str = call.argument<String>("type") ?: "alarm"
        val type = when (type_str) {
          "ringtone"     -> RingtoneManager.TYPE_RINGTONE
          "notification" -> RingtoneManager.TYPE_NOTIFICATION
          else           -> RingtoneManager.TYPE_ALARM
        }

        try {
          val mgr    = RingtoneManager(this).apply { setType(type) }
          val cursor = mgr.cursor
          val list   = mutableListOf<Map<String, String>>()
          while (cursor.moveToNext()) {
            list += mapOf(
              "title" to cursor.getString(RingtoneManager.TITLE_COLUMN_INDEX),
              "uri"   to mgr.getRingtoneUri(cursor.position).toString(),
            )
          }
          cursor.close()
          result.success(list)
        } catch (e: Exception) {
          result.error("RINGTONE_ERROR", e.message, null)
        }
      }
  }
}
