package com.opennomad.noctua

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper

/**
 * Foreground service that plays the alarm/timer ringtone with optional crescendo
 * and posts a persistent CATEGORY_ALARM notification with action buttons.
 *
 * Alarm notifications: Dismiss | Snooze Xm
 * Timer notifications: Dismiss | +Xm
 *
 * Companion-object fields are read from MainActivity via the getRingingAlarm
 * MethodChannel call so Flutter can detect a ringing alarm on resume.
 */
class AlarmRingtoneService : Service() {

  private var player:            MediaPlayer? = null
  private var crescendo_handler: Handler?     = null

  companion object {
    const val RINGING_NOTIF_ID = 77777
    const val RINGING_CHANNEL  = "noctua_ringing_v1"

    /** "alarm" | "timer" | "" (not ringing) */
    @Volatile var ringing_type: String = ""
    @Volatile var ringing_name: String = ""
  }

  override fun onCreate() {
    super.onCreate()
    ensureChannel()
  }

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    // Idempotent: ignore if already ringing (prevents double-start race).
    if (ringing_type.isNotEmpty()) return START_NOT_STICKY

    val sound_uri      = intent?.getStringExtra("sound_uri")       ?: ""
    val name           = intent?.getStringExtra("name")            ?: ""
    val type           = intent?.getStringExtra("type")            ?: "alarm"
    val crescendo_secs = intent?.getIntExtra("crescendo_secs", 30) ?: 30
    val snooze_mins    = intent?.getIntExtra("snooze_mins", 10)    ?: 10
    val add_mins       = intent?.getIntExtra("add_mins", 1)        ?: 1
    val req_code       = intent?.getIntExtra("req_code", 0)        ?: 0

    ringing_name = name
    ringing_type = type

    startForeground(RINGING_NOTIF_ID, buildNotification(name, type, sound_uri, snooze_mins, add_mins, req_code))
    playCrescendo(sound_uri, crescendo_secs)

    return START_NOT_STICKY
  }

  private fun ensureChannel() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
    val nm = getSystemService(NotificationManager::class.java)
    if (nm.getNotificationChannel(RINGING_CHANNEL) != null) return
    nm.createNotificationChannel(
      NotificationChannel(
        RINGING_CHANNEL,
        "Alarm ringing",
        NotificationManager.IMPORTANCE_HIGH,
      ).apply {
        description = "Shown while an alarm or timer is ringing"
        setSound(null, null)      // sound is played by MediaPlayer, not the channel
        enableVibration(false)
      }
    )
  }

  private fun buildNotification(
    name: String,
    type: String,
    sound_uri: String,
    snooze_mins: Int,
    add_mins: Int,
    req_code: Int,
  ): Notification {
    val title = name.ifEmpty { if (type == "timer") "Timer done" else "Alarm" }

    // Tapping the notification body opens the app.
    val tap_pi = PendingIntent.getActivity(
      this, 0,
      Intent(this, MainActivity::class.java).apply {
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
      },
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    // ── action: Dismiss ───────────────────────────────────────────────────────
    val dismiss_pi = PendingIntent.getBroadcast(
      this, AlarmActionReceiver.RC_DISMISS,
      Intent(AlarmActionReceiver.ACTION_DISMISS, null, this, AlarmActionReceiver::class.java),
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      Notification.Builder(this, RINGING_CHANNEL)
    } else {
      @Suppress("DEPRECATION")
      Notification.Builder(this)
    }

    builder
      .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
      .setContentTitle(title)
      .setContentText("Tap to open")
      .setContentIntent(tap_pi)
      .setFullScreenIntent(tap_pi, true)
      .setCategory(Notification.CATEGORY_ALARM)
      .setOngoing(true)
      .setOnlyAlertOnce(true)
      .addAction(buildAction(0, "Dismiss", dismiss_pi))

    if (type == "alarm") {
      // ── action: Snooze Xm ──────────────────────────────────────────────────
      val snooze_pi = PendingIntent.getBroadcast(
        this, AlarmActionReceiver.RC_SNOOZE,
        Intent(AlarmActionReceiver.ACTION_SNOOZE, null, this, AlarmActionReceiver::class.java).apply {
          putExtra("snooze_mins", snooze_mins)
          putExtra("sound_uri",   sound_uri)
          putExtra("name",        name)
          putExtra("add_mins",    add_mins)
        },
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
      )
      val snooze_label = "Snooze ${snooze_mins}m"
      builder.addAction(buildAction(0, snooze_label, snooze_pi))
    } else {
      // ── action: +Xm (timer) ────────────────────────────────────────────────
      val add_pi = PendingIntent.getBroadcast(
        this, AlarmActionReceiver.RC_ADD_MINS,
        Intent(AlarmActionReceiver.ACTION_ADD_MINS, null, this, AlarmActionReceiver::class.java).apply {
          putExtra("add_mins",    add_mins)
          putExtra("req_code",    req_code)
          putExtra("sound_uri",   sound_uri)
          putExtra("name",        name)
          putExtra("snooze_mins", snooze_mins)
        },
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
      )
      val add_label = "+${add_mins}m"
      builder.addAction(buildAction(0, add_label, add_pi))
    }

    return builder.build()
  }

  /** Thin helper to avoid the deprecated 3-arg addAction on API 23+. */
  private fun buildAction(icon: Int, title: String, pi: PendingIntent): Notification.Action =
    Notification.Action.Builder(icon, title, pi).build()

  private fun playCrescendo(uri_str: String, crescendo_secs: Int) {
    crescendo_handler?.removeCallbacksAndMessages(null)
    player?.stop()
    player?.release()
    player = null

    val uri: Uri = uri_str.takeIf { it.isNotEmpty() }
      ?.let { runCatching { Uri.parse(it) }.getOrNull() }
      ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)

    val mp = runCatching {
      MediaPlayer().apply {
        setAudioAttributes(
          AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
            .build()
        )
        setDataSource(this@AlarmRingtoneService, uri)
        isLooping = true
        setVolume(if (crescendo_secs > 0) 0f else 1f,
                  if (crescendo_secs > 0) 0f else 1f)
        prepare()
        start()
      }
    }.getOrElse {
      // Specified URI failed; retry once with the system default.
      if (uri_str.isNotEmpty()) { playCrescendo("", crescendo_secs); return }
      stopSelf()
      return
    }
    player = mp

    if (crescendo_secs <= 0) return   // instant-on: no ramp needed

    val total_steps = crescendo_secs * 10   // one step every 100 ms
    var step = 0
    crescendo_handler = Handler(Looper.getMainLooper())
    val tick = object : Runnable {
      override fun run() {
        step++
        val vol = (step.toFloat() / total_steps).coerceAtMost(1f)
        player?.setVolume(vol, vol)
        if (step < total_steps) crescendo_handler?.postDelayed(this, 100L)
      }
    }
    crescendo_handler?.postDelayed(tick, 100L)
  }

  override fun onDestroy() {
    crescendo_handler?.removeCallbacksAndMessages(null)
    crescendo_handler = null
    player?.stop()
    player?.release()
    player       = null
    ringing_type = ""
    ringing_name = ""
    @Suppress("DEPRECATION")
    stopForeground(true)
    super.onDestroy()
  }

  override fun onBind(intent: Intent?): IBinder? = null
}
