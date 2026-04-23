package com.opennomad.noctua

import android.app.Activity
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.os.Build
import android.os.Bundle
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView

/**
 * Dedicated full-screen alarm activity shown when an alarm fires.
 * Shows immediately (no Flutter load time) with alarm name and dismiss button.
 * Audio is handled entirely by AlarmRingtoneService.
 *
 * Launched by:
 *   1. AlarmRingtoneService fullScreenIntent notification (primary path)
 *   2. AlarmFireReceiver direct startActivity (fallback)
 */
class AlarmActivity : Activity() {

  private var alarmName: String = ""
  private var alarmType: String = "alarm"
  private var soundUri: String = ""
  private var snoozeMins: Int = 10

  override fun onCreate(savedInstanceState: Bundle?) {
    applyLockScreenFlags()
    super.onCreate(savedInstanceState)
    setContentView(R.layout.activity_alarm)

    alarmName  = intent.getStringExtra("name")      ?: ""
    alarmType  = intent.getStringExtra("type")      ?: "alarm"
    soundUri   = intent.getStringExtra("sound_uri") ?: ""
    snoozeMins = intent.getIntExtra("snooze_mins", 10)

    applyColors()

    val title_label = alarmName.ifEmpty { if (alarmType == "timer") "Timer" else "Alarm" }
    findViewById<TextView>(R.id.alarm_title).text = title_label
    findViewById<TextView>(R.id.alarm_time).text = java.text.SimpleDateFormat(
      "HH:mm", java.util.Locale.getDefault()
    ).format(java.util.Date())

    findViewById<Button>(R.id.btn_dismiss).setOnClickListener { dismiss() }

    val snooze_btn = findViewById<Button>(R.id.btn_snooze)
    val add_time_btn = findViewById<Button>(R.id.btn_add_time)
    if (alarmType == "timer") {
      snooze_btn.visibility = View.GONE
      add_time_btn.visibility = View.VISIBLE
      add_time_btn.setOnClickListener { addTime() }
    } else {
      snooze_btn.text = "Snooze ${snoozeMins}m"
      snooze_btn.setOnClickListener { snooze() }
    }
  }

  private fun applyColors() {
    val prefs   = getSharedPreferences("noctua_colors", Context.MODE_PRIVATE)
    val key     = if (alarmType == "timer") "timer" else "alarm"
    val bg      = prefs.getInt("${key}_bg",     Color.rgb(0x0A, 0x16, 0x28))
    val accent  = prefs.getInt("${key}_accent", Color.rgb(0x64, 0xB5, 0xF6))
    val text    = prefs.getInt("${key}_text",   Color.WHITE)

    // Background
    findViewById<View>(R.id.root_layout).setBackgroundColor(bg)

    // Title: 70% opacity of text color
    val title_color = Color.argb(
      0xB3,
      Color.red(text), Color.green(text), Color.blue(text),
    )
    findViewById<TextView>(R.id.alarm_title).setTextColor(title_color)

    // Time: full text color
    findViewById<TextView>(R.id.alarm_time).setTextColor(text)

    val density = resources.displayMetrics.density

    // Dismiss: solid accent pill, white text
    val dismiss_btn = findViewById<Button>(R.id.btn_dismiss)
    dismiss_btn.background = makeSolidPill(accent, 28f * density)
    dismiss_btn.setTextColor(Color.WHITE)

    // Snooze: ghost/outline pill, accent text
    val snooze_btn = findViewById<Button>(R.id.btn_snooze)
    snooze_btn.background = makeOutlinePill(accent, 24f * density, (1.5f * density).toInt())
    snooze_btn.setTextColor(accent)

    // Add Time: ghost/outline pill, accent text
    val add_time_btn = findViewById<Button>(R.id.btn_add_time)
    add_time_btn.background = makeOutlinePill(accent, 24f * density, (1.5f * density).toInt())
    add_time_btn.setTextColor(accent)
  }

  private fun makeSolidPill(color: Int, radius: Float): RippleDrawable {
    val bg = GradientDrawable().apply {
      shape = GradientDrawable.RECTANGLE
      cornerRadius = radius
      setColor(color)
    }
    val mask = GradientDrawable().apply {
      shape = GradientDrawable.RECTANGLE
      cornerRadius = radius
      setColor(Color.WHITE)
    }
    val ripple = ColorStateList.valueOf(Color.argb(0x40, 0, 0, 0))
    return RippleDrawable(ripple, bg, mask)
  }

  private fun makeOutlinePill(color: Int, radius: Float, stroke: Int): RippleDrawable {
    val bg = GradientDrawable().apply {
      shape = GradientDrawable.RECTANGLE
      cornerRadius = radius
      setStroke(stroke, color)
      setColor(Color.TRANSPARENT)
    }
    val mask = GradientDrawable().apply {
      shape = GradientDrawable.RECTANGLE
      cornerRadius = radius
      setColor(Color.WHITE)
    }
    val ripple = ColorStateList.valueOf(
      Color.argb(0x28, Color.red(color), Color.green(color), Color.blue(color))
    )
    return RippleDrawable(ripple, bg, mask)
  }

  private fun applyLockScreenFlags() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
      setShowWhenLocked(true)
      setTurnScreenOn(true)
    } else {
      @Suppress("DEPRECATION")
      window.addFlags(
        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
          WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
          WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
      )
    }
  }

  private fun dismiss() {
    stopService(Intent(this, AlarmRingtoneService::class.java))
    AlarmActionReceiver.setPendingAction("dismissed", 0)
    finish()
  }

  private fun snooze() {
    stopService(Intent(this, AlarmRingtoneService::class.java))
    val at = System.currentTimeMillis() + snoozeMins * 60_000L

    val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
    val firePi = PendingIntent.getBroadcast(
      this, 88888,
      Intent(this, AlarmFireReceiver::class.java).apply {
        putExtra("sound_uri",      soundUri)
        putExtra("name",           alarmName)
        putExtra("type",           "alarm")
        putExtra("crescendo_secs", 30)
        putExtra("snooze_mins",    snoozeMins)
        putExtra("req_code",       88888)
      },
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
    val showPi = PendingIntent.getActivity(
      this, 88888 + 100_000,
      Intent(this, MainActivity::class.java),
      PendingIntent.FLAG_IMMUTABLE,
    )
    am.setAlarmClock(AlarmManager.AlarmClockInfo(at, showPi), firePi)

    AlarmActionReceiver.setPendingAction("snoozed", 0)
    finish()
  }

  private fun addTime() {
    stopService(Intent(this, AlarmRingtoneService::class.java))
    val add_mins = 1
    val at = System.currentTimeMillis() + add_mins * 60_000L

    val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
    val firePi = PendingIntent.getBroadcast(
      this, 88888,
      Intent(this, AlarmFireReceiver::class.java).apply {
        putExtra("sound_uri",      soundUri)
        putExtra("name",           alarmName)
        putExtra("type",           "timer")
        putExtra("crescendo_secs", 0)
        putExtra("snooze_mins",    snoozeMins)
        putExtra("add_mins",       add_mins)
        putExtra("req_code",       88888)
      },
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
    val showPi = PendingIntent.getActivity(
      this, 88888 + 100_000,
      Intent(this, MainActivity::class.java),
      PendingIntent.FLAG_IMMUTABLE,
    )
    am.setAlarmClock(AlarmManager.AlarmClockInfo(at, showPi), firePi)

    AlarmActionReceiver.setPendingAction("added_minutes:$add_mins", 0)
    finish()
  }

  override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
    if (keyCode == KeyEvent.KEYCODE_VOLUME_UP || keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
      return true  // consume volume keys so they don't affect alarm volume
    }
    return super.onKeyDown(keyCode, event)
  }
}
