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
    
    private val instaTracker = InstagramTracker()
    private val ytTracker = YouTubeTracker()

    private var instaCount = 0
    private var youtubeCount = 0
    private var currentPackageName = ""
    private var lastScrollTime = 0L
    private var lastUiCheckTime = 0L

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

        if (eventPackage == "com.example.distract") return

        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            val actualActivePackage = rootInActiveWindow?.packageName?.toString() ?: eventPackage
            if (actualActivePackage == "com.android.systemui") return 
            
            currentPackageName = actualActivePackage
            
            if (!instaTracker.isTargetPlatform(currentPackageName) && !ytTracker.isTargetPlatform(currentPackageName)) {
                hideFloatingBirdOverlay()
                instaTracker.reset()
                ytTracker.reset()
                return
            }
        }

        if (!instaTracker.isTargetPlatform(currentPackageName) && !ytTracker.isTargetPlatform(currentPackageName)) return

        // UI Presence Scanner with Visibility Check
        val currentTime = System.currentTimeMillis()
        if (currentTime - lastUiCheckTime > 500) { 
            lastUiCheckTime = currentTime
            val rootNode = rootInActiveWindow
            if (rootNode != null) {
                Thread {
                    val inReels = checkIsReelsLayout(rootNode, currentPackageName)
                    mainHandler.post {
                        if (inReels) {
                            if (overlayView == null) showFloatingBirdOverlay()
                            updateOverlayUI()
                        } else {
                            hideFloatingBirdOverlay()
                        }
                    }
                    rootNode.recycle()
                }.start()
            }
        }

        // Scroll Tracking Logic
        if (event.eventType == AccessibilityEvent.TYPE_VIEW_SCROLLED) {
            val rootNode = rootInActiveWindow ?: return
            Thread {
                if (System.currentTimeMillis() - lastScrollTime > 300) {
                    var countUpdated = false

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
                        lastScrollTime = System.currentTimeMillis()
                        updateOverlayUI()
                        saveAndBroadcastCount()
                    }
                }
                rootNode.recycle()
            }.start()
        }
    }

    // UPDATED: Now strictly checks if the container is actually visible to the user!
    private fun checkIsReelsLayout(node: AccessibilityNodeInfo, pkg: String): Boolean {
        if (pkg == "com.instagram.android") {
            val reelsNodes = node.findAccessibilityNodeInfosByViewId("com.instagram.android:id/clips_video_container")
            // Must be strictly visible on screen, not just hidden in background cache
            return reelsNodes.any { it.isVisibleToUser }
        } else if (pkg == "com.google.android.youtube") {
            val r1 = node.findAccessibilityNodeInfosByViewId("com.google.android.youtube:id/reel_recycler")
            val r2 = node.findAccessibilityNodeInfosByViewId("com.google.android.youtube:id/reel_viewer_page")
            val r3 = node.findAccessibilityNodeInfosByViewId("com.google.android.youtube:id/shorts_player_view")
            
            return r1.any { it.isVisibleToUser } || r2.any { it.isVisibleToUser } || r3.any { it.isVisibleToUser }
        }
        return false
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
    }

    private fun hideFloatingBirdOverlay() {
        mainHandler.post {
            overlayView?.let { windowManager?.removeView(it); overlayView = null; counterTextView = null }
        }
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