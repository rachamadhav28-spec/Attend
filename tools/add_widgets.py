"""Adds the Android home screen widget(s) to the generated Flutter project."""
import os, re

PKG = 'com.madhav.attendtrack'
base = 'android/app/src/main'
kdir = os.path.join(base, 'kotlin', *PKG.split('.'))
os.makedirs(kdir, exist_ok=True)
os.makedirs(os.path.join(base, 'res', 'layout'), exist_ok=True)
os.makedirs(os.path.join(base, 'res', 'xml'), exist_ok=True)
os.makedirs(os.path.join(base, 'res', 'drawable'), exist_ok=True)


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
    android:description="@string/ring_widget_description"
    android:initialLayout="@layout/attend_ring_widget"
    android:minWidth="110dp"
    android:minHeight="110dp"
    android:targetCellWidth="2"
    android:targetCellHeight="2"
    android:resizeMode="none"
    android:updatePeriodMillis="1800000"
    android:widgetCategory="home_screen" />
''')

# strings.xml may not exist in a fresh project
sp = os.path.join(base, 'res', 'values')
os.makedirs(sp, exist_ok=True)
with open(os.path.join(sp, 'widget_strings.xml'), 'w') as f:
    f.write('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="ring_widget_description">Your overall attendance</string>
</resources>
''')

w('kotlin/' + PKG.replace('.', '/') + '/AttendRingWidget.kt', '''package com.madhav.attendtrack

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class AttendRingWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val pct = widgetData.getInt("overall_pct", 0).coerceIn(0, 100)
        val status = widgetData.getString("overall_status", "Open AttendTrack") ?: ""
        val bmp = ring(pct)
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.attend_ring_widget)
            views.setImageViewBitmap(R.id.ring_image, bmp)
            views.setTextViewText(R.id.ring_text, "$pct%")
            views.setTextViewText(R.id.status_text, status)
            val open = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            views.setOnClickPendingIntent(R.id.widget_root, open)
            appWidgetManager.updateAppWidget(id, views)
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
''')

# Register the receiver
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
print('widgets added')
