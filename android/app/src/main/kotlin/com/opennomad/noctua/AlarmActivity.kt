package com.opennomad.noctua

import android.app.Activity
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
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

    findViewById<TextView>(R.id.alarm_title).text = alarmName.ifEmpty { "Alarm" }
    findViewById<TextView>(R.id.alarm_time).text = java.text.SimpleDateFormat(
      "HH:mm", java.util.Locale.getDefault()
    ).format(java.util.Date())

    findViewById<Button>(R.id.btn_dismiss).setOnClickListener { dismiss() }

    val snoozeBtn = findViewById<Button>(R.id.btn_snooze)
    if (alarmType == "timer") {
      snoozeBtn.visibility = View.GONE
    } else {
      snoozeBtn.text = "Snooze ${snoozeMins}m"
      snoozeBtn.setOnClickListener { snooze() }
    }
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

  override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
    if (keyCode == KeyEvent.KEYCODE_VOLUME_UP || keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
      return true  // consume volume keys so they don't affect alarm volume
    }
    return super.onKeyDown(keyCode, event)
  }
}
