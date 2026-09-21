package com.example.china_holiday_reminder

import android.Manifest
import android.app.Activity
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.CalendarContract
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

/**
 * 日历桥：直接走 CalendarContract 静默写入 / 回读 / 删除事件。
 *
 * 事件以 SYNC_DATA1 中的唯一键（"chr:" 前缀）标识、SYNC_DATA2 存内容指纹，
 * 所有增删改仅作用于带该前缀的事件，绝不误伤用户自建日历事件。
 */
class CalendarBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val CHANNEL = "app/calendar_bridge"
        private const val PERMISSION_REQUEST_CODE = 41
        private val PERMISSIONS = arrayOf(
            Manifest.permission.READ_CALENDAR,
            Manifest.permission.WRITE_CALENDAR,
        )
    }

    private val channel = MethodChannel(messenger, CHANNEL).also {
        it.setMethodCallHandler(this)
    }
    private var pendingPermission: MethodChannel.Result? = null

    fun detach() {
        channel.setMethodCallHandler(null)
        pendingPermission?.success(false)
        pendingPermission = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasPermission" -> result.success(hasCalendarPermission())
            "requestPermission" -> requestCalendarPermission(result)
            "openAppSettings" -> {
                openAppSettings()
                result.success(null)
            }
            "listEvents" -> listEvents(call.argument<String>("prefix").orEmpty(), result)
            "insertEvent" -> {
                val args = call.arguments as? Map<*, *>
                if (args == null) result.error("bad_args", null, null) else insertEvent(args, result)
            }
            "deleteEvents" -> deleteEvents(call.argument<List<*>>("ids"), result)
            else -> result.notImplemented()
        }
    }

    fun handlePermissionResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != PERMISSION_REQUEST_CODE) return
        val granted = pendingPermission != null &&
            grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        pendingPermission?.success(granted)
        pendingPermission = null
    }

    private fun hasCalendarPermission(): Boolean = PERMISSIONS.all {
        ContextCompat.checkSelfPermission(activity, it) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestCalendarPermission(result: MethodChannel.Result) {
        if (hasCalendarPermission()) {
            result.success(true)
            return
        }
        pendingPermission?.success(false)
        pendingPermission = result
        ActivityCompat.requestPermissions(activity, PERMISSIONS, PERMISSION_REQUEST_CODE)
    }

    private fun openAppSettings() {
        val intent = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.fromParts("package", activity.packageName, null),
        )
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        activity.startActivity(intent)
    }

    private fun listEvents(prefix: String, result: MethodChannel.Result) {
        val projection = arrayOf(
            CalendarContract.Events._ID,
            CalendarContract.Events.SYNC_DATA1,
            CalendarContract.Events.SYNC_DATA2,
        )
        val rows = ArrayList<Map<String, Any?>>()
        activity.contentResolver.query(
            CalendarContract.Events.CONTENT_URI,
            projection,
            "${CalendarContract.Events.SYNC_DATA1} LIKE ?",
            arrayOf("$prefix%"),
            null,
        )?.use { cursor ->
            val idCol = cursor.getColumnIndexOrThrow(CalendarContract.Events._ID)
            val keyCol = cursor.getColumnIndexOrThrow(CalendarContract.Events.SYNC_DATA1)
            val hashCol = cursor.getColumnIndexOrThrow(CalendarContract.Events.SYNC_DATA2)
            while (cursor.moveToNext()) {
                val key = cursor.getString(keyCol) ?: continue
                rows.add(
                    mapOf(
                        "id" to cursor.getLong(idCol),
                        "key" to key,
                        "hash" to (cursor.getString(hashCol) ?: ""),
                    ),
                )
            }
        }
        result.success(rows)
    }

    private fun insertEvent(args: Map<*, *>, result: MethodChannel.Result) {
        val calendarId = pickWritableCalendar()
        if (calendarId == null) {
            result.error("no_calendar", "设备上没有找到可写入的日历", null)
            return
        }
        val reminderMinutes = (args["reminderMinutes"] as? Number)?.toInt()
        val values = ContentValues().apply {
            put(CalendarContract.Events.CALENDAR_ID, calendarId)
            put(CalendarContract.Events.TITLE, args["title"] as? String ?: "")
            put(CalendarContract.Events.DESCRIPTION, args["description"] as? String ?: "")
            put(CalendarContract.Events.DTSTART, (args["startMillis"] as Number).toLong())
            put(CalendarContract.Events.DTEND, (args["endMillis"] as Number).toLong())
            put(CalendarContract.Events.ALL_DAY, if (args["allDay"] == true) 1 else 0)
            put(CalendarContract.Events.EVENT_TIMEZONE, TimeZone.getDefault().id)
            put(CalendarContract.Events.SYNC_DATA1, args["key"] as? String)
            put(CalendarContract.Events.SYNC_DATA2, args["hash"] as? String)
            put(CalendarContract.Events.HAS_ALARM, if (reminderMinutes != null) 1 else 0)
        }
        val eventId = activity.contentResolver
            .insert(CalendarContract.Events.CONTENT_URI, values)
            ?.let { ContentUris.parseId(it) }
        if (eventId == null) {
            result.success(null)
            return
        }
        if (reminderMinutes != null) {
            val reminder = ContentValues().apply {
                put(CalendarContract.Reminders.CALENDAR_ID, calendarId)
                put(CalendarContract.Reminders.EVENT_ID, eventId)
                put(CalendarContract.Reminders.MINUTES, reminderMinutes)
                put(CalendarContract.Reminders.METHOD, CalendarContract.Reminders.METHOD_DEFAULT)
            }
            activity.contentResolver.insert(CalendarContract.Reminders.CONTENT_URI, reminder)
        }
        result.success(eventId)
    }

    private fun deleteEvents(ids: List<*>?, result: MethodChannel.Result) {
        var deleted = 0
        for (raw in ids.orEmpty()) {
            val id = (raw as? Number)?.toLong() ?: continue
            deleted += activity.contentResolver.delete(
                ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, id),
                null,
                null,
            )
        }
        result.success(deleted)
    }

    /** 选取可见且可写（contributor 及以上）的日历，主账户日历优先。 */
    private fun pickWritableCalendar(): Long? {
        val projection = arrayOf(CalendarContract.Calendars._ID)
        val selection =
            "${CalendarContract.Calendars.VISIBLE} = 1 AND " +
                "${CalendarContract.Calendars.DELETED} = 0 AND " +
                "${CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL} >= ?"
        val args = arrayOf(CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR.toString())
        val ids = ArrayList<Long>()
        activity.contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            projection,
            selection,
            args,
            "${CalendarContract.Calendars.IS_PRIMARY} DESC, " +
                CalendarContract.Calendars._ID.toString() + " ASC",
        )?.use { cursor ->
            val idCol = cursor.getColumnIndexOrThrow(CalendarContract.Calendars._ID)
            while (cursor.moveToNext()) ids.add(cursor.getLong(idCol))
        }
        return ids.firstOrNull()
    }
}
