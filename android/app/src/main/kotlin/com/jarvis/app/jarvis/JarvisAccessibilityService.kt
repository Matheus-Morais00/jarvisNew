package com.jarvis.app.jarvis

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent

class JarvisAccessibilityService : AccessibilityService() {
    override fun onAccessibilityEvent(event: AccessibilityEvent?) = Unit
    override fun onInterrupt() = Unit

    private fun gesture(action: String, x: Double?, y: Double?): Boolean {
        val metrics = resources.displayMetrics
        val px = ((x ?: .5) * metrics.widthPixels).toFloat()
        val py = ((y ?: .5) * metrics.heightPixels).toFloat()
        val path = Path()
        when (action) {
            "tap" -> path.moveTo(px, py)
            "swipeUp" -> { path.moveTo(px, py); path.lineTo(px, py - metrics.heightPixels * .35f) }
            "swipeDown" -> { path.moveTo(px, py); path.lineTo(px, py + metrics.heightPixels * .35f) }
            "swipeLeft" -> { path.moveTo(px, py); path.lineTo(px - metrics.widthPixels * .35f, py) }
            "swipeRight" -> { path.moveTo(px, py); path.lineTo(px + metrics.widthPixels * .35f, py) }
            else -> return false
        }
        val duration = if (action == "tap") 60L else 350L
        val stroke = GestureDescription.StrokeDescription(path, 0, duration)
        return dispatchGesture(GestureDescription.Builder().addStroke(stroke).build(), null, null)
    }

    private fun runAction(action: String, x: Double?, y: Double?): Boolean = when (action) {
        "back" -> performGlobalAction(GLOBAL_ACTION_BACK)
        "home" -> performGlobalAction(GLOBAL_ACTION_HOME)
        "recents" -> performGlobalAction(GLOBAL_ACTION_RECENTS)
        "scrollUp" -> gesture("swipeUp", x, y)
        "scrollDown" -> gesture("swipeDown", x, y)
        "swipeLeft", "swipeRight", "tap" -> gesture(action, x, y)
        else -> false
    }

    companion object {
        @Volatile private var instance: JarvisAccessibilityService? = null
        private val main = Handler(Looper.getMainLooper())

        fun perform(action: String, x: Double?, y: Double?): Boolean {
            val service = instance ?: return false
            var success = false
            main.post { success = service.runAction(action, x, y) }
            return true
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }
}
