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
 * Shows a persistent notification while alarms are scheduled within the threshold.
 * If multiple alarms, shows them as a list.
 * Tapping opens the app directly to the alarm screen.
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

    fun schedule(app: android.content.Context, alarms: List<Map<String, Any>>) {
      pending_alarms = alarms
      is_scheduled = true
      
      Handler(Looper.getMainLooper()).post {
        try {
          val nm = app.getSystemService(NotificationManager::class.java)
          nm.notify(NOTIF_ID, buildNotification(app, alarms))
        } catch (e: Exception) {
          // Ignore
        }
      }
      
      scheduleUpdate(app)
    }

    fun cancel(app: android.content.Context) {
      is_scheduled = false
      pending_alarms = emptyList()
      try {
        val nm = app.getSystemService(NotificationManager::class.java)
        nm.cancel(NOTIF_ID)
      } catch (e: Exception) {
        // Ignore
      }
    }

    private fun buildNotification(app: android.content.Context, alarms: List<Map<String, Any>>): Notification {
      val text = if (alarms.size == 1) {
        val alarm = alarms[0]
        val label = alarm["name"] as? String ?: ""
        val epoch_ms = (alarm["epoch_ms"] as? Number)?.toLong() ?: 0L
        val title = label.ifEmpty { "Alarm" }
        "$title • ${formatRemaining(epoch_ms)}"
      } else {
        // Multiple alarms — show count
        "${alarms.size} alarms"
      }

      val tap_pi = PendingIntent.getActivity(
        app, 0,
        Intent(app, MainActivity::class.java).apply {
          flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                  Intent.FLAG_ACTIVITY_CLEAR_TOP or
                  Intent.FLAG_ACTIVITY_SINGLE_TOP
          putExtra("screen", "alarm")
        },
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
      )

      val channel = NotificationChannel(CHANNEL, "Alarm countdown", NotificationManager.IMPORTANCE_LOW).apply {
        description = "Shows time remaining until alarm"
        setShowBadge(false)
      }

      val nm = app.getSystemService(NotificationManager::class.java)
      if (nm.getNotificationChannel(CHANNEL) == null) {
        nm.createNotificationChannel(channel)
      }

      return NotificationCompat.Builder(app, CHANNEL)
        .setSmallIcon(R.drawable.ic_alarm)
        .setContentTitle("Alarm")
        .setContentText(text)
        .setContentInfo(if (alarms.isNotEmpty()) "Alarm in" else null)
        .setContentIntent(tap_pi)
        .setOngoing(true)
        .setOnlyAlertOnce(true)
        .setPriority(NotificationCompat.PRIORITY_LOW)
        .setCategory(NotificationCompat.CATEGORY_ALARM)
        .setStyle(
          if (alarms.size > 1) {
            NotificationCompat.InboxStyle().also { style ->
              alarms.take(5).forEach { alarm ->
                val label = alarm["name"] as? String ?: ""
                val epoch_ms = (alarm["epoch_ms"] as? Number)?.toLong() ?: 0L
                val title = label.ifEmpty { "Alarm" }
                style.addLine("$title • ${formatRemaining(epoch_ms)}")
              }
              if (alarms.size > 5) {
                style.setSummaryText("+${alarms.size - 5} more")
              }
            }
          } else null
        )
        .build()
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
        // Remove any alarms that have passed
        val now = System.currentTimeMillis()
        val active = pending_alarms.filter { (it["epoch_ms"] as? Number)?.toLong() ?: 0L > now }
        
        if (is_scheduled && active.isNotEmpty()) {
          pending_alarms = active
          try {
            val nm = app.getSystemService(NotificationManager::class.java)
            nm.notify(NOTIF_ID, buildNotification(app, active))
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