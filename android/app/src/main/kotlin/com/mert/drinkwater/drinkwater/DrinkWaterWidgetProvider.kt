package com.mert.drinkwater.drinkwater

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import es.antonborri.home_widget.HomeWidgetPlugin

class DrinkWaterWidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == Intent.ACTION_USER_PRESENT ||
            intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE
        ) {
            val pendingResult = goAsync()
            WidgetUpdateHelper.fetchSensorAndRefreshWidgets(context) {
                try {
                    pendingResult.finish()
                } catch (_: Exception) {}
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        // En son bilinen veriyi anında çiz
        HomeWidgetPlugin.getData(context)
        WidgetUpdateHelper.updateAllWidgets(context)

        // Donanım sensöründen anlık adımı oku ve widget'ı yenile
        val pendingResult = goAsync()
        WidgetUpdateHelper.fetchSensorAndRefreshWidgets(context) {
            try {
                pendingResult.finish()
            } catch (_: Exception) {}
        }
    }
}
