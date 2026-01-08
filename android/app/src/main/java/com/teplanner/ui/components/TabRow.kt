package com.teplanner.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.teplanner.ui.theme.DividerColor
import com.teplanner.ui.theme.TextHint
import com.teplanner.ui.theme.TextPrimary

enum class HomeTab {
    RECENT,
    NEARBY
}

@Composable
fun HomeTabRow(
    selectedTab: HomeTab,
    onTabSelected: (HomeTab) -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(bottom = 16.dp)
    ) {
        TabItem(
            text = "最近",
            isSelected = selectedTab == HomeTab.RECENT,
            onClick = { onTabSelected(HomeTab.RECENT) },
            modifier = Modifier.weight(1f)
        )
        TabItem(
            text = "附近",
            isSelected = selectedTab == HomeTab.NEARBY,
            onClick = { onTabSelected(HomeTab.NEARBY) },
            modifier = Modifier.weight(1f)
        )
    }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(1.dp)
            .background(DividerColor)
    )
}

@Composable
private fun TabItem(
    text: String,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .clickable(onClick = onClick)
            .padding(vertical = 10.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = text,
            color = if (isSelected) TextPrimary else TextHint,
            fontSize = 15.sp
        )
        Spacer(modifier = Modifier.height(8.dp))
        if (isSelected) {
            Box(
                modifier = Modifier
                    .width(20.dp)
                    .height(2.dp)
                    .background(
                        color = TextPrimary,
                        shape = RoundedCornerShape(1.dp)
                    )
            )
        } else {
            Spacer(modifier = Modifier.height(2.dp))
        }
    }
}
