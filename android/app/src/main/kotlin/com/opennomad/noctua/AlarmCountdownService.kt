package com.opennomad.noctua

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Handler
import android.os.Looper
import androidx.core.app.NotificationCompat

/**
 * Shows a persistent notification while alarms or timers are scheduled within
 * the threshold. If multiple items, shows them as a list.
 * Tapping opens the app directly to the alarm or timer screen.
 * 
 * Uses regular notifications (not foreground service) to avoid background-start 
 * restrictions on Android 14+.
 */
class AlarmCountdownService : android.app.Service() {

  companion object {
    const val NOTIF_ID = 66000
    const val CHANNEL = "alarm_countdown_v1"

    @Volatile var is_scheduled = false
    @Volatile var pending_alarms: List<Map<String, Any>> = emptyList()
    @Volatile var pending_timers: List<Map<String, Any>> = emptyList()

    fun schedule(app: android.content.Context, alarms: List<Map<String, Any>>, timers: List<Map<String, Any>>) {
      pending_alarms = alarms
      pending_timers = timers
      is_scheduled = true
      
      Handler(Looper.getMainLooper()).post {
        try {
          val nm = app.getSystemService(NotificationManager::class.java)
          nm.notify(NOTIF_ID, buildNotification(app, alarms, timers))
        } catch (e: Exception) {
          // Ignore
        }
      }
      
      scheduleUpdate(app)
    }

    fun cancel(app: android.content.Context) {
      is_scheduled = false
      pending_alarms = emptyList()
      pending_timers = emptyList()
      try {
        val nm = app.getSystemService(NotificationManager::class.java)
        nm.cancel(NOTIF_ID)
      } catch (e: Exception) {
        // Ignore
      }
    }

    private fun buildNotification(app: android.content.Context, alarms: List<Map<String, Any>>, timers: List<Map<String, Any>>): Notification {
      val has_alarms = alarms.isNotEmpty()
      val has_timers = timers.isNotEmpty()

      val title = when {
        !has_alarms && !has_timers -> "Countdown"
        has_alarms && has_timers -> "Upcoming"
        has_alarms -> "Alarm"
        else -> "Timer"
      }

      val lines = mutableListOf<String>()

      if (has_alarms) {
        lines.add("Alarms")
        alarms.forEach { alarm ->
          val name = (alarm["name"] as? String)?.ifEmpty { null }
          val epoch_ms = (alarm["epoch_ms"] as? Number)?.toLong() ?: 0L
          lines.add("  • ${name ?: "Alarm"} • ${formatRemaining(epoch_ms)}")
        }
      }
      if (has_timers) {
        lines.add("Timers")
        timers.forEach { timer ->
          val name = (timer["name"] as? String)?.ifEmpty { null }
          val epoch_ms = (timer["epoch_ms"] as? Number)?.toLong() ?: 0L
          lines.add("  • ${name ?: "Timer"} • ${formatRemaining(epoch_ms)}")
        }
      }

      val text = if (lines.size <= 3) lines.joinToString("\n") else "${lines.size} items"

      // ContentIntent: go to alarm screen if there are alarms, otherwise timer screen
      val dest = if (has_alarms) "alarm" else "timer"
      val tap_pi = PendingIntent.getActivity(
        app, 0,
        Intent(app, MainActivity::class.java).apply {
          flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                  Intent.FLAG_ACTIVITY_CLEAR_TOP or
                  Intent.FLAG_ACTIVITY_SINGLE_TOP
          putExtra("screen", dest)
        },
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
      )

      val channel = NotificationChannel(CHANNEL, "Alarm & Timer countdown", NotificationManager.IMPORTANCE_LOW).apply {
        description = "Shows time remaining until alarm or timer"
        setShowBadge(false)
      }

      val nm = app.getSystemService(NotificationManager::class.java)
      if (nm.getNotificationChannel(CHANNEL) == null) {
        nm.createNotificationChannel(channel)
      }

      val builder = NotificationCompat.Builder(app, CHANNEL)
        .setSmallIcon(R.drawable.ic_alarm)
        .setContentTitle(title)
        .setContentText(text)
        .setContentIntent(tap_pi)
        .setOngoing(true)
        .setOnlyAlertOnce(true)
        .setPriority(NotificationCompat.PRIORITY_LOW)
        .setCategory(NotificationCompat.CATEGORY_ALARM)

      if (lines.size > 3 || (has_alarms && has_timers)) {
        builder.setStyle(
          NotificationCompat.InboxStyle().also { style ->
            lines.take(6).forEach { style.addLine(it) }
            if (lines.size > 6) {
              style.setSummaryText("+${lines.size - 6} more")
            }
          }
        )
      }

      return builder.build()
    }

    private fun formatRemaining(epoch_ms: Long): String {
      if (epoch_ms <= 0) return "Scheduled"
      val now = System.currentTimeMillis()
      val diff = epoch_ms - now
      if (diff <= 0) return "Now"

      val hours = diff / (1000 * 60 * 60)
      val mins = (diff / (1000 * 60)) % 60

      return when {
        hours > 24 -> "${hours / 24}d ${hours % 24}h"
        hours > 0 -> "${hours}h ${mins}m"
        mins > 0 -> "${mins}m"
        else -> "<1m"
      }
    }

    private fun scheduleUpdate(app: android.content.Context) {
      Handler(Looper.getMainLooper()).postDelayed({
        val now = System.currentTimeMillis()
        val active_alarms = pending_alarms.filter { (it["epoch_ms"] as? Number)?.toLong() ?: 0L > now }
        val active_timers = pending_timers.filter { (it["epoch_ms"] as? Number)?.toLong() ?: 0L > now }
        
        if (is_scheduled && (active_alarms.isNotEmpty() || active_timers.isNotEmpty())) {
          pending_alarms = active_alarms
          pending_timers = active_timers
          try {
            val nm = app.getSystemService(NotificationManager::class.java)
            nm.notify(NOTIF_ID, buildNotification(app, active_alarms, active_timers))
          } catch (e: Exception) {
            // Ignore
          }
          scheduleUpdate(app)
        } else {
          cancel(app)
        }
      }, 60 * 1000L)
    }
  }

  override fun onCreate() {
    super.onCreate()
  }

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    // Called on service start but we actually receive data via schedule() static method
    return START_NOT_STICKY
  }

  override fun onDestroy() {
    is_scheduled = false
    super.onDestroy()
  }

  override fun onBind(intent: Intent?): android.os.IBinder? = null
}