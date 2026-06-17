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
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.LinearLayout
import android.widget.TextView

class ReelTrackingService : AccessibilityService() {

    private var windowManager: WindowManager? = null
    private var overlayView: LinearLayout? = null
    private var counterTextView: TextView? = null
    private var currentCount = 0
    
    private var currentPackageName = ""
    private val mainHandler = Handler(Looper.getMainLooper())

    private var lastScrollTime = 0L
    private var lastInstaIndex = -1
    private var lastYoutubeIndex = -1

    override fun onServiceConnected() {
        super.onServiceConnected()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        
        val prefs = getSharedPreferences("ReelPrefs", Context.MODE_PRIVATE)
        currentCount = prefs.getInt("daily_count", 0)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        val eventPackage = event.packageName?.toString() ?: return

        // 1. The Blind Spot: Ignore our own floating bird
        if (eventPackage == "com.example.distract") {
            return
        }

        // 2. Handle App Switching (Strictly ONLY when the main window changes)
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            
            // Double Verification: Make sure we check the actual window on the screen, 
            // not just a background system transition.
            val actualActivePackage = rootInActiveWindow?.packageName?.toString() ?: eventPackage

            // Ignore transient system UI flashes (like the volume slider popping up)
            if (actualActivePackage == "com.android.systemui") return
            
            if (currentPackageName != actualActivePackage) {
                currentPackageName = actualActivePackage
                adjustOverlayVisibility()
                
                // Reset anti-wiggle indexes when leaving the app
                if (actualActivePackage != "com.instagram.android" && actualActivePackage != "com.google.android.apps.youtube") {
                    lastInstaIndex = -1
                    lastYoutubeIndex = -1
                }
            }
        }

        // --- BATTERY SAVER: Ignore all scroll/tap events outside target apps ---
        if (currentPackageName != "com.instagram.android" && currentPackageName != "com.google.android.apps.youtube") {
            return
        }

        // 3. Handle Scrolling (The Smart Algorithm)
        if (event.eventType == AccessibilityEvent.TYPE_VIEW_SCROLLED) {
            
            val fromIndex = event.fromIndex
            val toIndex = event.toIndex
            
            if (fromIndex == -1 || toIndex == -1) return
            if ((toIndex - fromIndex) > 1) return // Ignore fast scrolling through comment sections

            val rootNode = rootInActiveWindow ?: return
            
            Thread {
                if (isReelsOrShortsLayout(rootNode, currentPackageName)) {
                    val currentTime = System.currentTimeMillis()
                    
                    if (currentTime - lastScrollTime > 400) {
                        var isValidForwardSwipe = false

                        if (currentPackageName == "com.instagram.android") {
                            if (lastInstaIndex != -1 && fromIndex > lastInstaIndex) isValidForwardSwipe = true
                            lastInstaIndex = fromIndex
                        } 
                        else if (currentPackageName == "com.google.android.apps.youtube") {
                            if (lastYoutubeIndex != -1 && fromIndex > lastYoutubeIndex) isValidForwardSwipe = true
                            lastYoutubeIndex = fromIndex
                        }

                        if (isValidForwardSwipe) {
                            currentCount++
                            lastScrollTime = currentTime
                            updateOverlayUI()
                            saveAndBroadcastCount()
                        }
                    }
                }
                rootNode.recycle()
            }.start()
        }
    }

    private fun isReelsOrShortsLayout(node: AccessibilityNodeInfo, pkg: String): Boolean {
        if (pkg == "com.instagram.android") {
            val reelNodes = node.findAccessibilityNodeInfosByViewId("com.instagram.android:id/clips_video_container")
            if (reelNodes.isNotEmpty()) return true
        } else if (pkg == "com.google.android.apps.youtube") {
            val shortsNodes = node.findAccessibilityNodeInfosByViewId("com.google.android.apps.youtube:id/shorts_player_view")
            if (shortsNodes.isNotEmpty()) return true
        }
        return false
    }

    private fun adjustOverlayVisibility() {
        val isTargetApp = currentPackageName == "com.instagram.android" || 
                          currentPackageName == "com.google.android.apps.youtube"

        mainHandler.post {
            if (isTargetApp && overlayView == null) {
                showFloatingBirdOverlay()
            } else if (!isTargetApp && overlayView != null) {
                hideFloatingBirdOverlay()
            }
        }
    }

    private fun showFloatingBirdOverlay() {
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.TOP or Gravity.END
        params.x = 40
        params.y = 250

        overlayView = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(30, 16, 30, 16)
            
            val backgroundShape = GradientDrawable()
            backgroundShape.shape = GradientDrawable.RECTANGLE
            backgroundShape.cornerRadius = 50f
            backgroundShape.setColor(Color.parseColor("#E91E63")) 
            background = backgroundShape
            
            counterTextView = TextView(this@ReelTrackingService).apply {
                text = "🦩 $currentCount"
                textSize = 18f
                setTextColor(Color.WHITE)
                setTypeface(null, android.graphics.Typeface.BOLD)
            }
            addView(counterTextView)
        }
        
        windowManager?.addView(overlayView, params)
    }

    private fun hideFloatingBirdOverlay() {
        overlayView?.let {
            windowManager?.removeView(it)
            overlayView = null
            counterTextView = null
        }
    }

    private fun updateOverlayUI() {
        mainHandler.post {
            counterTextView?.text = "🦩 $currentCount"
        }
    }

    private fun saveAndBroadcastCount() {
        val prefs = getSharedPreferences("ReelPrefs", Context.MODE_PRIVATE)
        prefs.edit().putInt("daily_count", currentCount).apply()

        val intent = Intent("com.example.distract.UPDATE_COUNT")
        intent.putExtra("count", currentCount)
        sendBroadcast(intent)
    }

    override fun onInterrupt() {}
}