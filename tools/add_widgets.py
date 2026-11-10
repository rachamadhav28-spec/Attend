"""Adds the Android home screen widget to the generated Flutter project.
No extra plugin: Flutter talks to the widget through one MethodChannel."""
import os

PKG = 'com.madhav.attendtrack'
base = 'android/app/src/main'
kdir = os.path.join(base, 'kotlin', *PKG.split('.'))
for d in ('res/layout', 'res/xml', 'res/drawable', 'res/values'):
    os.makedirs(os.path.join(base, d), exist_ok=True)
os.makedirs(kdir, exist_ok=True)


def w(path, text):
    with open(os.path.join(base, path), 'w') as f:
        f.write(text)


w('res/drawable/widget_bg.xml', '''<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#355E3B" />
    <corners android:radius="28dp" />
</shape>
''')

w('res/layout/attend_ring_widget.xml', '''<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/widget_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="@drawable/widget_bg"
    android:gravity="center"
    android:orientation="vertical"
    android:padding="12dp">

    <FrameLayout
        android:layout_width="88dp"
        android:layout_height="88dp">

        <ImageView
            android:id="@+id/ring_image"
            android:layout_width="match_parent"
            android:layout_height="match_parent"
            android:contentDescription="Overall attendance" />

        <TextView
            android:id="@+id/ring_text"
            android:layout_width="match_parent"
            android:layout_height="match_parent"
            android:gravity="center"
            android:textColor="#FFFFFF"
            android:textSize="20sp"
            android:textStyle="bold" />
    </FrameLayout>

    <TextView
        android:id="@+id/status_text"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_marginTop="8dp"
        android:textColor="#FFFFFF"
        android:textSize="14sp"
        android:textStyle="bold" />
</LinearLayout>
''')

w('res/xml/attend_ring_widget_info.xml', '''<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:initialLayout="@layout/attend_ring_widget"
    android:minWidth="110dp"
    android:minHeight="110dp"
    android:targetCellWidth="2"
    android:targetCellHeight="2"
    android:resizeMode="none"
    android:updatePeriodMillis="1800000"
    android:widgetCategory="home_screen" />
''')

w('kotlin/com/madhav/attendtrack/AttendRingWidget.kt', '''package com.madhav.attendtrack

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.widget.RemoteViews

class AttendRingWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) {
        val p = context.getSharedPreferences("attend_widget", Context.MODE_PRIVATE)
        render(context, mgr, ids, p.getInt("pct", 0), p.getString("status", "Open AttendTrack") ?: "")
    }

    companion object {
        fun render(context: Context, mgr: AppWidgetManager, ids: IntArray, pctIn: Int, status: String) {
            val pct = pctIn.coerceIn(0, 100)
            val bmp = ring(pct)
            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val open = if (launch != null)
                PendingIntent.getActivity(context, 0, launch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            else null
            for (id in ids) {
                val v = RemoteViews(context.packageName, R.layout.attend_ring_widget)
                v.setImageViewBitmap(R.id.ring_image, bmp)
                v.setTextViewText(R.id.ring_text, "$pct%")
                v.setTextViewText(R.id.status_text, status)
                if (open != null) v.setOnClickPendingIntent(R.id.widget_root, open)
                mgr.updateAppWidget(id, v)
            }
        }

        private fun ring(pct: Int): Bitmap {
            val size = 264
            val stroke = 24f
            val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val c = Canvas(bmp)
            val p = Paint(Paint.ANTI_ALIAS_FLAG)
            p.style = Paint.Style.STROKE
            p.strokeWidth = stroke
            p.strokeCap = Paint.Cap.ROUND
            val r = RectF(stroke, stroke, size - stroke, size - stroke)
            p.color = 0x40FFFFFF
            c.drawArc(r, 0f, 360f, false, p)
            p.color = if (pct >= 75) 0xFFFFFDD0.toInt() else 0xFFFFB4AB.toInt()
            c.drawArc(r, -90f, 360f * pct / 100f, false, p)
            return bmp
        }
    }
}
''')

# MainActivity: one channel so Flutter can refresh the widget. Failures here
# are swallowed so they can never stop the app from starting.
w('kotlin/com/madhav/attendtrack/MainActivity.kt', '''package com.madhav.attendtrack

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "attendtrack/widget")
            .setMethodCallHandler { call, result ->
                if (call.method == "update") {
                    try {
                        val pct = call.argument<Int>("pct") ?: 0
                        val status = call.argument<String>("status") ?: ""
                        getSharedPreferences("attend_widget", Context.MODE_PRIVATE)
                            .edit().putInt("pct", pct).putString("status", status).apply()
                        val mgr = AppWidgetManager.getInstance(this)
                        val ids = mgr.getAppWidgetIds(ComponentName(this, AttendRingWidget::class.java))
                        if (ids.isNotEmpty()) AttendRingWidget.render(this, mgr, ids, pct, status)
                    } catch (e: Exception) {
                    }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
''')

m = os.path.join(base, 'AndroidManifest.xml')
t = open(m).read()
if 'AttendRingWidget' not in t:
    rec = ('    <receiver android:name=".AttendRingWidget" android:exported="true">\n'
           '        <intent-filter>\n'
           '            <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />\n'
           '        </intent-filter>\n'
           '        <meta-data android:name="android.appwidget.provider"\n'
           '            android:resource="@xml/attend_ring_widget_info" />\n'
           '    </receiver>\n'
           '    </application>')
    t = t.replace('</application>', rec, 1)
    open(m, 'w').write(t)
print('widget added')
