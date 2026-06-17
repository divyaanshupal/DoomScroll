package com.example.distract

import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

interface PlatformTracker {
    val packageName: String
    var lastIndex: Int
    
    fun isTargetPlatform(activePackage: String): Boolean {
        return activePackage == packageName
    }

    fun checkForNewSwipe(rootNode: AccessibilityNodeInfo, event: AccessibilityEvent): Boolean

    fun reset() {
        lastIndex = -1
    }
}

// 📸 Instagram Logic
class InstagramTracker : PlatformTracker {
    override val packageName = "com.instagram.android"
    override var lastIndex = -1

    override fun checkForNewSwipe(rootNode: AccessibilityNodeInfo, event: AccessibilityEvent): Boolean {
        val className = event.className?.toString() ?: ""
        if (!className.contains("RecyclerView") && !className.contains("ViewPager")) return false

        val isReels = rootNode.findAccessibilityNodeInfosByViewId("com.instagram.android:id/clips_video_container").isNotEmpty()
        if (!isReels) return false

        val currentIndex = event.fromIndex
        if (currentIndex == -1) return false 

        // Instagram indices increment cleanly upwards
        if (lastIndex != -1 && currentIndex > lastIndex) {
            lastIndex = currentIndex
            return true 
        }
        lastIndex = currentIndex
        return false
    }
}

// 📺 YouTube Logic
class YouTubeTracker : PlatformTracker {
    override val packageName = "com.google.android.youtube"
    override var lastIndex = -1
    private var lastScrollTime = 0L

    override fun checkForNewSwipe(rootNode: AccessibilityNodeInfo, event: AccessibilityEvent): Boolean {
        // 1. Isolate the Shorts UI strictly
        val hasReelRecycler = rootNode.findAccessibilityNodeInfosByViewId("com.google.android.youtube:id/reel_recycler").isNotEmpty()
        val hasReelViewer = rootNode.findAccessibilityNodeInfosByViewId("com.google.android.youtube:id/reel_viewer_page").isNotEmpty()
        val hasShortsPlayer = rootNode.findAccessibilityNodeInfosByViewId("com.google.android.youtube:id/shorts_player_view").isNotEmpty()
        
        // If we are watching a normal horizontal video, ignore completely
        if (!hasReelRecycler && !hasReelViewer && !hasShortsPlayer) return false

        // 2. Ignore scrolls if the user is reading the comments!
        val hasCommentPanel = rootNode.findAccessibilityNodeInfosByViewId("com.google.android.youtube:id/engagement_panel_root").isNotEmpty()
        val hasBottomSheet = rootNode.findAccessibilityNodeInfosByViewId("com.google.android.youtube:id/bottom_sheet").isNotEmpty()
        if (hasCommentPanel || hasBottomSheet) return false

        // 3. Smart Index Reading
        var currentIndex = event.fromIndex
        if (currentIndex < 0) {
            currentIndex = event.toIndex
        }

        val currentTime = System.currentTimeMillis()

        // 4. Handle the swipe logic
        if (currentIndex > -1) {
            // YouTube recycles views in a loop (e.g., 0, 1, 2, 0, 1, 2)
            // If the index CHANGED, they moved to a new video.
            if (lastIndex != -1 && currentIndex != lastIndex) {
                // 400ms debounce prevents double-counting weird Android multi-touch bounces
                if (currentTime - lastScrollTime > 400) {
                    lastIndex = currentIndex
                    lastScrollTime = currentTime
                    return true
                }
            }
            lastIndex = currentIndex
        } else {
            // 5. Bulletproof Fallback
            // If YouTube actively hides the index (returns -1) on your device version,
            // we use a time-based heuristic. If a scroll event happens and it's been
            // more than 1.2 seconds since the last count, we consider it a new video.
            if (currentTime - lastScrollTime > 1200) {
                lastScrollTime = currentTime
                return true
            }
        }

        return false
    }
}