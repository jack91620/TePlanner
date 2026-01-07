package com.teplanner.ui.components

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.teplanner.ui.theme.DarkSurface
import com.teplanner.ui.theme.TextTertiary

enum class PanelState {
    COLLAPSED,
    HALF,
    EXPANDED
}

@Composable
fun DraggableBottomSheet(
    panelState: PanelState,
    onStateChange: (PanelState) -> Unit,
    collapsedHeight: Dp = 140.dp,
    halfHeight: Dp = 400.dp,
    expandedHeight: Dp? = null,
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit
) {
    val configuration = LocalConfiguration.current
    val density = LocalDensity.current
    val screenHeight = configuration.screenHeightDp.dp
    val actualExpandedHeight = expandedHeight ?: (screenHeight * 0.85f)

    val targetHeight = when (panelState) {
        PanelState.COLLAPSED -> collapsedHeight
        PanelState.HALF -> halfHeight
        PanelState.EXPANDED -> actualExpandedHeight
    }

    val animatedHeight by animateDpAsState(
        targetValue = targetHeight,
        animationSpec = tween(durationMillis = 300),
        label = "panelHeight"
    )

    var dragOffset by remember { mutableFloatStateOf(0f) }
    var isDragging by remember { mutableStateOf(false) }

    val currentHeight = if (isDragging) {
        with(density) {
            (targetHeight.toPx() - dragOffset).toDp().coerceIn(collapsedHeight, actualExpandedHeight)
        }
    } else {
        animatedHeight
    }

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(currentHeight)
            .background(
                color = DarkSurface,
                shape = RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp)
            )
    ) {
        Column(
            modifier = Modifier.fillMaxSize()
        ) {
            // Drag Handle
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .pointerInput(Unit) {
                        detectVerticalDragGestures(
                            onDragStart = {
                                isDragging = true
                                dragOffset = 0f
                            },
                            onDragEnd = {
                                isDragging = false
                                val currentHeightPx = targetHeight.toPx() - dragOffset
                                val collapsedPx = collapsedHeight.toPx()
                                val halfPx = halfHeight.toPx()
                                val expandedPx = actualExpandedHeight.toPx()

                                val newState = when {
                                    currentHeightPx < (collapsedPx + halfPx) / 2 -> PanelState.COLLAPSED
                                    currentHeightPx < (halfPx + expandedPx) / 2 -> PanelState.HALF
                                    else -> PanelState.EXPANDED
                                }

                                if (newState != panelState) {
                                    onStateChange(newState)
                                }
                                dragOffset = 0f
                            },
                            onDragCancel = {
                                isDragging = false
                                dragOffset = 0f
                            },
                            onVerticalDrag = { _, dragAmount ->
                                dragOffset += dragAmount
                            }
                        )
                    }
                    .padding(vertical = 12.dp),
                contentAlignment = Alignment.Center
            ) {
                Box(
                    modifier = Modifier
                        .width(32.dp)
                        .height(4.dp)
                        .background(
                            color = TextTertiary,
                            shape = RoundedCornerShape(2.dp)
                        )
                )
            }

            // Content
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 16.dp),
                content = content
            )
        }
    }
}
