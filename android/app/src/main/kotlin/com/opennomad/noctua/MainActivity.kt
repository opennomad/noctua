package com.opennomad.noctua

import android.media.Ringtone
import android.media.RingtoneManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private var _current_ringtone: Ringtone? = null

  override fun configureFlutterEngine(engine: FlutterEngine) {
    super.configureFlutterEngine(engine)

    MethodChannel(engine.dartExecutor.binaryMessenger, "noctua/ringtones")
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "list" -> {
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

          "preview" -> {
            val uri_str = call.argument<String>("uri") ?: ""
            _current_ringtone?.stop()
            _current_ringtone = null
            try {
              val uri = if (uri_str.isEmpty())
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
              else
                android.net.Uri.parse(uri_str)
              val ringtone = RingtoneManager.getRingtone(this, uri)
              if (ringtone != null) {
                ringtone.isLooping = false
                ringtone.play()
                _current_ringtone = ringtone
              }
              result.success(null)
            } catch (e: Exception) {
              result.error("PREVIEW_ERROR", e.message, null)
            }
          }

          "stopPreview" -> {
            _current_ringtone?.stop()
            _current_ringtone = null
            result.success(null)
          }

          else -> result.notImplemented()
        }
      }
  }
}
