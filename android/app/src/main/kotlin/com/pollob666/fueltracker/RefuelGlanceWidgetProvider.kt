package com.pollob666.fueltracker

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class RefuelGlanceWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_refuel_glance).apply {
                val vehicleName = widgetData.getString("widget_vehicle_name", "Fuel Tracker") ?: "Fuel Tracker"
                val remainingFuel = widgetData.getString("widget_remaining_fuel", "-- L") ?: "-- L"
                val dteText = widgetData.getString("widget_dte_text", "-- km") ?: "-- km"
                val odoText = widgetData.getString("widget_last_odo", "-- km") ?: "-- km"
                val lastDate = widgetData.getString("widget_last_date", "No records") ?: "No records"

                setTextViewText(R.id.widget_vehicle_name, vehicleName)
                setTextViewText(R.id.widget_remaining_fuel, remainingFuel)
                setTextViewText(R.id.widget_dte, dteText)
                setTextViewText(R.id.widget_odometer, odoText)
                setTextViewText(R.id.widget_last_refuel, "Last fill: $lastDate")

                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java
                )
                setOnClickPendingIntent(R.id.widget_root_layout, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
