package com.example.distract

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.LinearLayout
import android.widget.TextView

class ReelTrackingService : AccessibilityService() {

    private var windowManager: WindowManager? = null
    private var overlayView: LinearLayout? = null
    private var counterTextView: TextView? = null
    
    // Instantiate our isolated logic engines
    private val instaTracker = InstagramTracker()
    private val ytTracker = YouTubeTracker()

    private var instaCount = 0
    private var youtubeCount = 0
    private var currentPackageName = ""
    private var lastScrollTime = 0L

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onServiceConnected() {
        super.onServiceConnected()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        
        val prefs = getSharedPreferences("ReelPrefs", Context.MODE_PRIVATE)
        instaCount = prefs.getInt("insta_count", 0)
        youtubeCount = prefs.getInt("youtube_count", 0)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        val eventPackage = event.packageName?.toString() ?: return

        // 1. Blind Spot: Ignore our own floating pink bird
        if (eventPackage == "com.example.distract") return

        // 2. Handle Window Swaps cleanly
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            val actualActivePackage = rootInActiveWindow?.packageName?.toString() ?: eventPackage
            if (actualActivePackage == "com.android.systemui") return 
            
            if (currentPackageName != actualActivePackage) {
                currentPackageName = actualActivePackage
                adjustOverlayVisibility()
                
                // Reset index history when leaving apps so going back doesn't break counting
                if (!instaTracker.isTargetPlatform(currentPackageName) && !ytTracker.isTargetPlatform(currentPackageName)) {
                    instaTracker.reset()
                    ytTracker.reset()
                }
            }
        }

        // Drop events immediately if not in target apps (saves battery)
        if (!instaTracker.isTargetPlatform(currentPackageName) && !ytTracker.isTargetPlatform(currentPackageName)) return

        // 3. Pass scroll events directly to our Tracker Engines
        if (event.eventType == AccessibilityEvent.TYPE_VIEW_SCROLLED) {
            val rootNode = rootInActiveWindow ?: return
            
            Thread {
                val currentTime = System.currentTimeMillis()
                // Anti-spam debounce
                if (currentTime - lastScrollTime > 300) {
                    var countUpdated = false

                    // Let the engine decide if it was a real video swipe
                    // FIX: Passing the full 'event' instead of 'event.fromIndex'
                    if (instaTracker.isTargetPlatform(currentPackageName)) {
                        if (instaTracker.checkForNewSwipe(rootNode, event)) {
                            instaCount++
                            countUpdated = true
                        }
                    } else if (ytTracker.isTargetPlatform(currentPackageName)) {
                        if (ytTracker.checkForNewSwipe(rootNode, event)) {
                            youtubeCount++
                            countUpdated = true
                        }
                    }

                    if (countUpdated) {
                        lastScrollTime = currentTime
                        updateOverlayUI()
                        saveAndBroadcastCount()
                    }
                }
                rootNode.recycle()
            }.start()
        }
    }

    private fun adjustOverlayVisibility() {
        val isTargetApp = instaTracker.isTargetPlatform(currentPackageName) || ytTracker.isTargetPlatform(currentPackageName)
        mainHandler.post {
            if (isTargetApp && overlayView == null) showFloatingBirdOverlay()
            else if (!isTargetApp && overlayView != null) hideFloatingBirdOverlay()
            
            if (isTargetApp && overlayView != null) updateOverlayUI()
        }
    }

    private fun showFloatingBirdOverlay() {
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT, WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY, WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE, PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.TOP or Gravity.END
        params.x = 40
        params.y = 250

        overlayView = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(30, 16, 30, 16)
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 50f
                setColor(Color.parseColor("#E91E63")) 
            }
            counterTextView = TextView(this@ReelTrackingService).apply {
                textSize = 16f
                setTextColor(Color.WHITE)
                setTypeface(null, android.graphics.Typeface.BOLD)
            }
            addView(counterTextView)
        }
        windowManager?.addView(overlayView, params)
        updateOverlayUI()
    }

    private fun hideFloatingBirdOverlay() {
        overlayView?.let { windowManager?.removeView(it); overlayView = null; counterTextView = null }
    }

    private fun updateOverlayUI() {
        mainHandler.post {
            if (instaTracker.isTargetPlatform(currentPackageName)) counterTextView?.text = "📸 $instaCount"
            else if (ytTracker.isTargetPlatform(currentPackageName)) counterTextView?.text = "📺 $youtubeCount"
        }
    }

    private fun saveAndBroadcastCount() {
        getSharedPreferences("ReelPrefs", Context.MODE_PRIVATE).edit()
            .putInt("insta_count", instaCount)
            .putInt("youtube_count", youtubeCount).apply()

        val intent = Intent("com.example.distract.UPDATE_COUNT")
        intent.putExtra("insta", instaCount)
        intent.putExtra("yt", youtubeCount)
        sendBroadcast(intent)
    }

    override fun onInterrupt() {}
}