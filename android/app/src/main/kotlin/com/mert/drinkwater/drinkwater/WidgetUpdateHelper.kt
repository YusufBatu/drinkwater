package com.mert.drinkwater.drinkwater

import android.Manifest
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.Looper
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean

object WidgetUpdateHelper {

    fun updateAllWidgets(context: Context) {
        val appWidgetManager = AppWidgetManager.getInstance(context) ?: return
        val widgetData = HomeWidgetPlugin.getData(context)

        val waterText = widgetData.getString("water_text", "0 / 2500 ml") ?: "0 / 2500 ml"
        val waterPercent = widgetData.getString("water_percent", "%0") ?: "%0"
        val waterProgress = widgetData.getInt("water_progress", 0)

        val stepText = widgetData.getString("step_text", "0 / 8000") ?: "0 / 8000"
        val stepPercent = widgetData.getString("step_percent", "%0") ?: "%0"
        val stepProgress = widgetData.getInt("step_progress", 0)

        // Ortak Tıklama PendingIntent
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 1. 2x2 Widget'ları Güncelle
        val provider2x2 = ComponentName(context, DrinkWaterWidgetProvider::class.java)
        val ids2x2 = appWidgetManager.getAppWidgetIds(provider2x2)
        if (ids2x2 != null && ids2x2.isNotEmpty()) {
            for (id in ids2x2) {
                val views = RemoteViews(context.packageName, R.layout.drinkwater_widget).apply {
                    setTextViewText(R.id.widget_water_text, waterText)
                    setTextViewText(R.id.widget_water_percent, waterPercent)
                    setProgressBar(R.id.widget_water_progress, 100, waterProgress.coerceIn(0, 100), false)

                    setTextViewText(R.id.widget_steps_text, stepText)
                    setTextViewText(R.id.widget_steps_percent, stepPercent)
                    setProgressBar(R.id.widget_steps_progress, 100, stepProgress.coerceIn(0, 100), false)

                    setOnClickPendingIntent(R.id.widget_container, pendingIntent)
                }
                appWidgetManager.updateAppWidget(id, views)
            }
        }

        // 2. 2x1 Widget'ları Güncelle
        val provider2x1 = ComponentName(context, DrinkWaterWidget2x1Provider::class.java)
        val ids2x1 = appWidgetManager.getAppWidgetIds(provider2x1)
        if (ids2x1 != null && ids2x1.isNotEmpty()) {
            for (id in ids2x1) {
                val views = RemoteViews(context.packageName, R.layout.drinkwater_widget_2x1).apply {
                    setTextViewText(R.id.widget_water_text, waterText)
                    setTextViewText(R.id.widget_water_percent, waterPercent)
                    setProgressBar(R.id.widget_water_progress, 100, waterProgress.coerceIn(0, 100), false)

                    setTextViewText(R.id.widget_steps_text, stepText)
                    setTextViewText(R.id.widget_steps_percent, stepPercent)
                    setProgressBar(R.id.widget_steps_progress, 100, stepProgress.coerceIn(0, 100), false)

                    setOnClickPendingIntent(R.id.widget_container, pendingIntent)
                }
                appWidgetManager.updateAppWidget(id, views)
            }
        }
    }

    fun fetchSensorAndRefreshWidgets(context: Context, onComplete: (() -> Unit)? = null) {
        val hasPermission = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACTIVITY_RECOGNITION
        ) == PackageManager.PERMISSION_GRANTED

        val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        val stepSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)

        if (!hasPermission || sensorManager == null || stepSensor == null) {
            updateAllWidgets(context)
            onComplete?.invoke()
            return
        }

        val isFinished = AtomicBoolean(false)
        val handler = Handler(Looper.getMainLooper())

        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent?) {
                if (event != null && event.values.isNotEmpty()) {
                    if (isFinished.compareAndSet(false, true)) {
                        try {
                            sensorManager.unregisterListener(this)
                        } catch (_: Exception) {}

                        val rawSensorSteps = event.values[0].toInt()
                        processRawSteps(context, rawSensorSteps)
                        updateAllWidgets(context)
                        onComplete?.invoke()
                    }
                }
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }

        handler.postDelayed({
            if (isFinished.compareAndSet(false, true)) {
                try {
                    sensorManager.unregisterListener(listener)
                } catch (_: Exception) {}
                updateAllWidgets(context)
                onComplete?.invoke()
            }
        }, 1500)

        try {
            sensorManager.registerListener(listener, stepSensor, SensorManager.SENSOR_DELAY_UI)
        } catch (_: Exception) {
            if (isFinished.compareAndSet(false, true)) {
                updateAllWidgets(context)
                onComplete?.invoke()
            }
        }
    }

    private fun processRawSteps(context: Context, rawSensorSteps: Int) {
        val widgetData = HomeWidgetPlugin.getData(context)
        val todayKey = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        val savedDateKey = widgetData.getString("step_date_key", "") ?: ""
        var baseline = widgetData.getInt("step_baseline", -1)
        val stepTarget = widgetData.getInt("step_target_raw", 8000)

        if (savedDateKey == todayKey && baseline >= 0) {
            if (rawSensorSteps < baseline) {
                baseline = rawSensorSteps
                widgetData.edit().putInt("step_baseline", baseline).apply()
            }

            val calculated = rawSensorSteps - baseline
            if (calculated >= 0) {
                val todaySteps = calculated.coerceAtMost(999999)
                val stepPercent = if (stepTarget > 0) ((todaySteps.toDouble() / stepTarget) * 100).toInt() else 0
                val stepText = "$todaySteps / $stepTarget"
                val stepPercentText = "%$stepPercent"
                val stepProgress = stepPercent.coerceIn(0, 100)

                widgetData.edit().apply {
                    putString("step_text", stepText)
                    putString("step_percent", stepPercentText)
                    putInt("step_progress", stepProgress)
                    putInt("today_steps", todaySteps)
                    apply()
                }
            }
        }
    }
}
