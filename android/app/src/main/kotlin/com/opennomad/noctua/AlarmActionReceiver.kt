package com.opennomad.noctua

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Handles notification action button taps: Dismiss, Snooze, and +X min.
 *
 * Each action:
 *   1. Stops AlarmRingtoneService immediately.
 *   2. Performs the appropriate follow-up (reschedule for snooze/add-mins).
 *   3. Raises MainActivity so Flutter can update its UI (except snooze, which
 *      is a silent "remind me later" — the sheet stays until the user sees it).
 *
 * Pending actions are stored in companion-object fields so MainActivity can
 * push them to Flutter via MethodChannel.invokeMethod in onNewIntent, and
 * AlarmService.checkRinging() can poll them on cold-start / warm-resume.
 */
class AlarmActionReceiver : BroadcastReceiver() {

  companion object {
    const val ACTION_DISMISS  = "com.opennomad.noctua.ACTION_DISMISS"
    const val ACTION_SNOOZE   = "com.opennomad.noctua.ACTION_SNOOZE"
    const val ACTION_ADD_MINS = "com.opennomad.noctua.ACTION_ADD_MINS"

    // Request codes for notification action PendingIntents (must not collide
    // with RINGING_NOTIF_ID 77777 or the fire/show RC offsets in MainActivity).
    const val RC_DISMISS  = 77778
    const val RC_SNOOZE   = 77779
    const val RC_ADD_MINS = 77780

    // Snooze alarm RC — same as AlarmService.snooze_nid so cancellation works.
    private const val SNOOZE_FIRE_RC  = 88888
    private const val SHOW_RC_OFFSET  = 100_000

    /** Set by each action handler; consumed by MainActivity.onNewIntent. */
    @Volatile var pending_action:   String = ""
    @Volatile var pending_add_mins: Int    = 0

    fun setPendingAction(action: String, addMins: Int = 0) {
      pending_action = action
      pending_add_mins = addMins
    }

    fun consumeAction(): String {
      val a = pending_action
      pending_action = ""
      return a
    }
    fun consumeAddMins(): Int {
      val m = pending_add_mins
      pending_add_mins = 0
      return m
    }
  }

  override fun onReceive(context: Context, intent: Intent) {
    context.stopService(Intent(context, AlarmRingtoneService::class.java))

    when (intent.action) {

      ACTION_DISMISS -> {
        pending_action = "dismissed"
        raiseApp(context)
      }

      ACTION_SNOOZE -> {
        val snooze_mins = intent.getIntExtra("snooze_mins", 10)
        val sound_uri   = intent.getStringExtra("sound_uri") ?: ""
        val name        = intent.getStringExtra("name")      ?: ""
        val add_mins    = intent.getIntExtra("add_mins", 1)
        val at          = System.currentTimeMillis() + snooze_mins * 60_000L

        val am = context.getSystemService(AlarmManager::class.java)
        val fire_pi = PendingIntent.getBroadcast(
          context, SNOOZE_FIRE_RC,
          Intent(context, AlarmFireReceiver::class.java).apply {
            putExtra("sound_uri",      sound_uri)
            putExtra("name",           name)
            putExtra("type",           "alarm")
            putExtra("crescendo_secs", 30)
            putExtra("snooze_mins",    snooze_mins)
            putExtra("add_mins",       add_mins)
            putExtra("req_code",       SNOOZE_FIRE_RC)
          },
          PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val show_pi = PendingIntent.getActivity(
          context, SNOOZE_FIRE_RC + SHOW_RC_OFFSET,
          Intent(context, MainActivity::class.java),
          PendingIntent.FLAG_IMMUTABLE,
        )
        am.setAlarmClock(AlarmManager.AlarmClockInfo(at, show_pi), fire_pi)

        // Raise the app so the dismiss sheet closes (user may be looking at it).
        pending_action = "snoozed"
        raiseApp(context)
      }

      ACTION_ADD_MINS -> {
        val add_mins    = intent.getIntExtra("add_mins",    1)
        val req_code    = intent.getIntExtra("req_code",    0)
        val sound_uri   = intent.getStringExtra("sound_uri") ?: ""
        val name        = intent.getStringExtra("name")       ?: ""
        val snooze_mins = intent.getIntExtra("snooze_mins", 10)
        val at          = System.currentTimeMillis() + add_mins * 60_000L

        val am = context.getSystemService(AlarmManager::class.java)
        val fire_pi = PendingIntent.getBroadcast(
          context, req_code,
          Intent(context, AlarmFireReceiver::class.java).apply {
            putExtra("sound_uri",      sound_uri)
            putExtra("name",           name)
            putExtra("type",           "timer")
            putExtra("crescendo_secs", 0)
            putExtra("snooze_mins",    snooze_mins)
            putExtra("add_mins",       add_mins)
            putExtra("req_code",       req_code)
          },
          PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val show_pi = PendingIntent.getActivity(
          context, req_code + SHOW_RC_OFFSET,
          Intent(context, MainActivity::class.java),
          PendingIntent.FLAG_IMMUTABLE,
        )
        am.setAlarmClock(AlarmManager.AlarmClockInfo(at, show_pi), fire_pi)

        pending_action   = "added_minutes"
        pending_add_mins = add_mins
        raiseApp(context)
      }
    }
  }

  private fun raiseApp(context: Context) {
    context.startActivity(
      Intent(context, MainActivity::class.java).apply {
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
      }
    )
  }
}
