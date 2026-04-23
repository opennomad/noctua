package com.opennomad.noctua

import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager

/**
 * Receives AlarmManager.setAlarmClock() broadcasts when an alarm or timer fires.
 *
 * Two-pronged approach for raising the app:
 *   1. Start AlarmRingtoneService (foreground service → MediaPlayer + fullScreenIntent).
 *   2. Call startActivity() directly — setAlarmClock BroadcastReceiver callbacks are
 *      exempt from Android 10+ background-activity-start restrictions without needing
 *      USE_FULL_SCREEN_INTENT.
 */
class AlarmFireReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    // Cancel countdown notification when alarm fires
    AlarmCountdownService.cancel(context)

    // Wake lock to ensure screen turns on and CPU stays awake
    val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
    val wakeLock = pm.newWakeLock(
      PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
        PowerManager.ACQUIRE_CAUSES_WAKEUP or
        PowerManager.ON_AFTER_RELEASE,
      "noctua:alarm_wake"
    )
    wakeLock.acquire(30_000L)  // 30 second timeout

    // Dismiss keyguard so the activity can appear on locked devices
    val km = context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
    if (km.isKeyguardLocked) {
      @Suppress("DEPRECATION")
      val kgLock = km.newKeyguardLock("noctua:keyguard")
      kgLock.disableKeyguard()
    }

    val svc = Intent(context, AlarmRingtoneService::class.java).also {
      it.putExtra("sound_uri",      intent.getStringExtra("sound_uri")       ?: "")
      it.putExtra("name",           intent.getStringExtra("name")            ?: "")
      it.putExtra("type",           intent.getStringExtra("type")            ?: "alarm")
      it.putExtra("crescendo_secs", intent.getIntExtra("crescendo_secs", 30))
      it.putExtra("snooze_mins",    intent.getIntExtra("snooze_mins", 10))
      it.putExtra("add_mins",       intent.getIntExtra("add_mins",     1))
      it.putExtra("req_code",       intent.getIntExtra("req_code",     0))
    }
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      context.startForegroundService(svc)
    } else {
      context.startService(svc)
    }

    // Direct raise — try simple startActivity first as AlarmManager
    // callbacks are exempt from background restrictions
    context.startActivity(
      Intent(context, MainActivity::class.java).apply {
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
      }
    )
  }
}
