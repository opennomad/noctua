package com.opennomad.noctua

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

  // Ringtone held for settings-panel previews (not alarm playback).
  private var _preview_ringtone: Ringtone? = null

  // Stored so onNewIntent can push notification-button actions to Flutter.
  private var _alarms_channel: MethodChannel? = null

  companion object {
    // Offset added to alarm req_code to get a distinct req_code for the
    // show PendingIntent (AlarmClockInfo status-bar icon).
    private const val SHOW_RC_OFFSET = 100_000
  }

// Apply flags that let this Activity appear over the lock screen.
  // Must be called in both onCreate (cold start) and onNewIntent (warm raise).
  private fun applyLockScreenFlags() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
      setShowWhenLocked(true)
      setTurnScreenOn(true)
    } else {
      @Suppress("DEPRECATION")
      window.addFlags(
        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
          WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
      )
    }
  }

  private fun clearLockScreenFlags() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
      setShowWhenLocked(false)
      setTurnScreenOn(false)
    } else {
      @Suppress("DEPRECATION")
      window.clearFlags(
        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
          WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
      )
    }
  }

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    applyLockScreenFlags()
  }

  override fun onResume() {
    super.onResume()
    applyLockScreenFlags()
  }

  override fun onPause() {
    super.onPause()
    clearLockScreenFlags()
  }

  // Called when AlarmFireReceiver (or a notification button) raises the already-
  // running Activity via FLAG_ACTIVITY_SINGLE_TOP.
  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    applyLockScreenFlags()

    // Navigate to the appropriate screen based on notification tap
    val dest = intent.getStringExtra("destination")
    if (!dest.isNullOrEmpty()) {
      _alarms_channel?.invokeMethod("navigateTo", mapOf("screen" to dest))
    }

    // Push any pending notification-button action to Flutter immediately so the
    // UI can update without waiting for the next checkRinging() poll.
    val action   = AlarmActionReceiver.consumeAction()
    val add_mins = AlarmActionReceiver.consumeAddMins()
    when (action) {
      "dismissed"     -> _alarms_channel?.invokeMethod("onDismissed",   null)
      "snoozed"       -> _alarms_channel?.invokeMethod("onSnoozed",     null)
      "added_minutes" -> _alarms_channel?.invokeMethod("onAddedMinutes", add_mins)
    }
  }

  override fun configureFlutterEngine(engine: FlutterEngine) {
    super.configureFlutterEngine(engine)

    // ── Ringtone listing and settings-panel preview ───────────────────────────
    MethodChannel(engine.dartExecutor.binaryMessenger, "noctua/ringtones")
      .setMethodCallHandler { call, result ->
        when (call.method) {

          "list" -> {
            val type = when (call.argument<String>("type") ?: "alarm") {
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
            _preview_ringtone?.stop()
            _preview_ringtone = null
            try {
              val uri = if (uri_str.isEmpty())
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
              else
                android.net.Uri.parse(uri_str)
              RingtoneManager.getRingtone(this, uri)?.also {
                it.isLooping = false
                it.play()
                _preview_ringtone = it
              }
              result.success(null)
            } catch (e: Exception) {
              result.error("PREVIEW_ERROR", e.message, null)
            }
          }

          "stopPreview" -> {
            _preview_ringtone?.stop()
            _preview_ringtone = null
            result.success(null)
          }

          else -> result.notImplemented()
        }
      }

    // ── Alarm / timer scheduling via native AlarmManager ─────────────────────
    _alarms_channel = MethodChannel(engine.dartExecutor.binaryMessenger, "noctua/alarms")
    _alarms_channel!!.setMethodCallHandler { call, result ->
      when (call.method) {

        // Schedule one alarm/timer via AlarmManager.setAlarmClock().
        // req_code uniquely identifies this alarm for later cancellation.
        "scheduleAlarm" -> {
          val epoch_ms = call.argument<Long>("ms")
            ?: return@setMethodCallHandler result.error("BAD_ARG", "ms required", null)
          val req_code = call.argument<Int>("req_code")
            ?: return@setMethodCallHandler result.error("BAD_ARG", "req_code required", null)
          val sound_uri      = call.argument<String>("sound_uri")    ?: ""
          val name           = call.argument<String>("name")         ?: ""
          val type           = call.argument<String>("type")         ?: "alarm"
          val crescendo_secs = call.argument<Int>("crescendo_secs")  ?: 30
          val snooze_mins    = call.argument<Int>("snooze_mins")     ?: 10
          val add_mins       = call.argument<Int>("add_mins")        ?: 1

          val am = getSystemService(AlarmManager::class.java)
          val fire_pi = PendingIntent.getBroadcast(
            this, req_code,
            Intent(this, AlarmFireReceiver::class.java).apply {
              putExtra("sound_uri",      sound_uri)
              putExtra("name",           name)
              putExtra("type",           type)
              putExtra("crescendo_secs", crescendo_secs)
              putExtra("snooze_mins",    snooze_mins)
              putExtra("add_mins",       add_mins)
              putExtra("req_code",       req_code)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
          )
          // show_pi: tapped from the status-bar alarm-clock icon.
          val show_pi = PendingIntent.getActivity(
            this, req_code + SHOW_RC_OFFSET,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE,
          )
          am.setAlarmClock(AlarmManager.AlarmClockInfo(epoch_ms, show_pi), fire_pi)
          result.success(null)
        }

        "cancelAlarm" -> {
          val req_code = call.argument<Int>("req_code")
            ?: return@setMethodCallHandler result.error("BAD_ARG", "req_code required", null)
          val am = getSystemService(AlarmManager::class.java)
          val pi = PendingIntent.getBroadcast(
            this, req_code,
            Intent(this, AlarmFireReceiver::class.java),
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
          )
          if (pi != null) am.cancel(pi)
          result.success(null)
        }

        // Start AlarmRingtoneService directly (foreground-expiry path where
        // the app is already in the foreground when the timer fires).
        "startRingtone" -> {
          val svc = Intent(this, AlarmRingtoneService::class.java).apply {
            putExtra("sound_uri",      call.argument<String>("sound_uri")    ?: "")
            putExtra("name",           call.argument<String>("name")         ?: "")
            putExtra("type",           call.argument<String>("type")         ?: "alarm")
            putExtra("crescendo_secs", call.argument<Int>("crescendo_secs")  ?: 0)
            putExtra("snooze_mins",    call.argument<Int>("snooze_mins")     ?: 10)
            putExtra("add_mins",       call.argument<Int>("add_mins")        ?: 1)
            putExtra("req_code",       call.argument<Int>("req_code")        ?: 0)
          }
          if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(svc)
          } else {
            startService(svc)
          }
          result.success(null)
        }

        "stopRingtone" -> {
          stopService(Intent(this, AlarmRingtoneService::class.java))
          result.success(null)
        }

        "scheduleCountdown" -> {
          val alarms_raw = call.argument<List<*>>("alarms")
          val alarms: List<Map<String, Any>> = alarms_raw?.mapNotNull { item ->
            (item as? Map<*, *>)?.let { map ->
              mapOf(
                "name" to (map["name"] as? String ?: ""),
                "epoch_ms" to ((map["epoch_ms"] as? Number)?.toLong() ?: 0L)
              )
            }
          } ?: emptyList()
          if (alarms.isNotEmpty()) {
            AlarmCountdownService.schedule(this, alarms)
          } else {
            AlarmCountdownService.cancel(this)
          }
          result.success(null)
        }

        "cancelCountdown" -> {
          AlarmCountdownService.cancel(this)
          result.success(null)
        }

        // Store alarm/timer screen colors so AlarmActivity can apply them
        // without Flutter being loaded.
        "setColors" -> {
          val p = getSharedPreferences("noctua_colors", Context.MODE_PRIVATE).edit()
          p.putInt("alarm_bg",     call.argument<Int>("alarm_bg")     ?: 0)
          p.putInt("alarm_accent", call.argument<Int>("alarm_accent") ?: 0)
          p.putInt("alarm_text",   call.argument<Int>("alarm_text")   ?: 0)
          p.putInt("timer_bg",     call.argument<Int>("timer_bg")     ?: 0)
          p.putInt("timer_accent", call.argument<Int>("timer_accent") ?: 0)
          p.putInt("timer_text",   call.argument<Int>("timer_text")   ?: 0)
          p.apply()
          result.success(null)
        }

        // Returns {"type": "alarm"|"timer", "name": "..."} while ringing, else null.
        "getRingingAlarm" -> {
          val t = AlarmRingtoneService.ringing_type
          result.success(
            if (t.isEmpty()) null
            else mapOf("type" to t, "name" to AlarmRingtoneService.ringing_name)
          )
        }

        // Returns a pending action string set by AlarmActionReceiver, then clears it.
        // Format: "dismissed" | "snoozed" | "added_minutes:<N>" | null.
        "getPendingAction" -> {
          val action   = AlarmActionReceiver.consumeAction()
          val add_mins = AlarmActionReceiver.consumeAddMins()
          result.success(
            when (action) {
              "added_minutes" -> "added_minutes:$add_mins"
              ""              -> null
              else            -> action
            }
          )
        }

        else -> result.notImplemented()
      }
    }
  }
}
