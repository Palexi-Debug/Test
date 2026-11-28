package de.palexi.schulportal

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import org.json.JSONObject
import java.util.Calendar
import java.util.Locale

/**
 * Homescreen-Widget: aktuelle bzw. nächste Stunde. Die App speichert den
 * Wochenplan als JSON ({"days": {"2026-11-28": [{"s":480,"e":525,"n":"Mathe","r":"R 1","x":false}]}}),
 * das Widget rechnet daraus selbst die laufende Stunde aus (auch ohne offene App).
 */
class ScheduleWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) {
            manager.updateAppWidget(id, build(context))
        }
    }

    companion object {
        private const val PREFS = "schedule_widget"
        private const val KEY = "data"

        fun save(context: Context, json: String) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().putString(KEY, json).apply()
        }

        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, ScheduleWidgetProvider::class.java))
            for (id in ids) {
                manager.updateAppWidget(id, build(context))
            }
        }

        private fun hm(minutes: Int): String =
            String.format(Locale.GERMANY, "%02d:%02d", minutes / 60, minutes % 60)

        private fun line(l: JSONObject): String {
            val room = l.optString("r", "")
            return hm(l.getInt("s")) + "–" + hm(l.getInt("e")) + (if (room.isNotEmpty()) " · $room" else "")
        }

        fun build(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.schedule_widget)

            var title = "Stundenplan"
            var main = "Noch keine Daten"
            var sub = "App öffnen zum Aktualisieren"
            var next = ""

            try {
                val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null)
                if (raw != null) {
                    val days = JSONObject(raw).getJSONObject("days")
                    val cal = Calendar.getInstance()
                    val key = String.format(
                        Locale.US, "%04d-%02d-%02d",
                        cal.get(Calendar.YEAR), cal.get(Calendar.MONTH) + 1, cal.get(Calendar.DAY_OF_MONTH)
                    )
                    val nowMin = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
                    if (days.has(key)) {
                        val arr = days.getJSONArray(key)
                        var current: JSONObject? = null
                        var upcoming: JSONObject? = null
                        var after: JSONObject? = null
                        for (i in 0 until arr.length()) {
                            val l = arr.getJSONObject(i)
                            val s = l.getInt("s")
                            val e = l.getInt("e")
                            if (s <= nowMin && nowMin < e) {
                                current = l
                            } else if (s > nowMin) {
                                if (upcoming == null) upcoming = l else if (after == null) after = l
                            }
                        }
                        val shown = current ?: upcoming
                        if (shown == null) {
                            title = "Heute"
                            main = if (arr.length() == 0) "Kein Unterricht" else "Schule aus"
                            sub = if (arr.length() == 0) "" else "Schönen Feierabend"
                        } else {
                            title = if (current != null) "Jetzt" else "Als Nächstes"
                            main = shown.optString("n", "")
                            sub = line(shown) + (if (shown.optBoolean("x", false)) " · Vertretung" else "")
                            val follow = if (current != null) upcoming else after
                            if (follow != null) {
                                next = "Danach: " + follow.optString("n", "") + " " + hm(follow.getInt("s"))
                            }
                        }
                    } else {
                        title = "Heute"
                        main = "Keine Daten für heute"
                    }
                }
            } catch (e: Exception) {
                main = "Daten nicht lesbar"
                sub = "App öffnen zum Aktualisieren"
            }

            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_main, main)
            views.setTextViewText(R.id.widget_sub, sub)
            views.setTextViewText(R.id.widget_next, next)

            val intent = Intent(context, MainActivity::class.java)
            val pending = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pending)
            return views
        }
    }
}
