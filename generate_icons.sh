#!/bin/bash

# TePlanner 图标生成脚本
# 使用 ImageMagick 生成高质量 PNG 图标

ICON_DIR="/home/ubuntu/TePlanner/miniprogram/assets/icons"
SIZE=64  # 基础尺寸

# 确保目录存在
mkdir -p "$ICON_DIR"

echo "开始生成图标..."

# ===========================================
# 1. 地图标记图标 (Map Markers)
# ===========================================

# 起点标记 - 绿色圆形带车辆图标
convert -size ${SIZE}x${SIZE} xc:transparent \
    -fill "#22C55E" -draw "circle 32,28 32,4" \
    -fill "#16A34A" -draw "polygon 32,52 20,32 44,32" \
    -fill "white" -draw "roundrectangle 22,16,42,28,3,3" \
    -fill "white" -draw "circle 26,32 26,30" \
    -fill "white" -draw "circle 38,32 38,30" \
    "$ICON_DIR/origin-marker.png"
echo "✓ origin-marker.png"

# 终点标记 - 红色水滴形状
convert -size ${SIZE}x${SIZE} xc:transparent \
    -fill "#EF4444" -draw "circle 32,24 32,4" \
    -fill "#EF4444" -draw "polygon 32,56 16,28 48,28" \
    -fill "white" -draw "circle 32,24 32,16" \
    -fill "#EF4444" -draw "circle 32,24 32,20" \
    "$ICON_DIR/destination-marker.png"
echo "✓ destination-marker.png"

# 充电站标记 - 橙色闪电
convert -size ${SIZE}x${SIZE} xc:transparent \
    -fill "#F97316" -draw "circle 32,28 32,4" \
    -fill "#EA580C" -draw "polygon 32,52 20,32 44,32" \
    -fill "white" -draw "polygon 36,12 24,30 30,30 28,44 40,26 34,26" \
    "$ICON_DIR/charging-marker.png"
echo "✓ charging-marker.png"

# 特斯拉车辆标记 - 蓝色车辆
convert -size ${SIZE}x${SIZE} xc:transparent \
    -fill "#3B82F6" -draw "circle 32,28 32,4" \
    -fill "#2563EB" -draw "polygon 32,52 20,32 44,32" \
    -fill "white" -draw "roundrectangle 20,18,44,32,6,6" \
    -fill "#3B82F6" -draw "roundrectangle 22,22,42,30,4,4" \
    -fill "white" -draw "circle 24,34 24,32" \
    -fill "white" -draw "circle 40,34 40,32" \
    "$ICON_DIR/tesla-car-marker.png"
echo "✓ tesla-car-marker.png"

# ===========================================
# 2. 充电站类型图标
# ===========================================

# 超级充电站 - 红色T标志
convert -size ${SIZE}x${SIZE} xc:transparent \
    -fill "#E31937" -draw "circle 32,32 32,4" \
    -fill "white" -font "DejaVu-Sans-Bold" -pointsize 32 \
    -gravity center -draw "text 0,2 'T'" \
    "$ICON_DIR/supercharger.png"
echo "✓ supercharger.png"

# 目的地充电站 - 灰色闪电
convert -size ${SIZE}x${SIZE} xc:transparent \
    -fill "#6B7280" -draw "circle 32,32 32,4" \
    -fill "white" -draw "polygon 36,14 22,34 30,34 28,50 42,30 34,30" \
    "$ICON_DIR/destination-charger.png"
echo "✓ destination-charger.png"

# 服务中心 - 蓝色扳手
convert -size ${SIZE}x${SIZE} xc:transparent \
    -fill "#3B82F6" -draw "circle 32,32 32,4" \
    -fill "white" -draw "polygon 24,20 28,24 20,44 24,48 44,28 48,24 44,20 40,24 28,24" \
    "$ICON_DIR/service-center.png"
echo "✓ service-center.png"

# ===========================================
# 3. 底部导航图标 (Tab Bar)
# ===========================================

# 路线图标 - 普通状态
convert -size ${SIZE}x${SIZE} xc:transparent \
    -fill "none" -stroke "#9CA3AF" -strokewidth 3 \
    -draw "path 'M 16,48 Q 32,16 48,32 Q 32,48 48,16'" \
    -fill "#9CA3AF" -draw "circle 16,48 16,45" \
    -fill "#9CA3AF" -draw "circle 48,16 48,13" \
    "$ICON_DIR/route.png"
echo "✓ route.png"

# 路线图标 - 选中状态
convert -size ${SIZE}x${SIZE} xc:transparent \
    -fill "none" -stroke "#3B82F6" -strokewidth 3 \
    -draw "path 'M 16,48 Q 32,16 48,32 Q 32,48 48,16'" \
    -fill "#3B82F6" -draw "circle 16,48 16,45" \
    -fill "#3B82F6" -draw "circle 48,16 48,13" \
    "$ICON_DIR/route-active.png"
echo "✓ route-active.png"

# 我的图标 - 普通状态
convert -size ${SIZE}x${SIZE} xc:transparent \
    -fill "none" -stroke "#9CA3AF" -strokewidth 3 \
    -draw "circle 32,20 32,10" \
    -draw "path 'M 16,52 Q 16,36 32,36 Q 48,36 48,52'" \
    "$ICON_DIR/profile.png"
echo "✓ profile.png"

# 我的图标 - 选中状态
convert -size ${SIZE}x${SIZE} xc:transparent \
    -fill "#3B82F6" -stroke "#3B82F6" -strokewidth 3 \
    -draw "circle 32,20 32,10" \
    -draw "path 'M 16,52 Q 16,36 32,36 Q 48,36 48,52'" \
    "$ICON_DIR/profile-active.png"
echo "✓ profile-active.png"

# ===========================================
# 4. 功能图标
# ===========================================

# 搜索图标
convert -size ${SIZE}x${SIZE} xc:transparent \
    -fill "none" -stroke "#6B7280" -strokewidth 4 \
    -draw "circle 28,28 28,12" \
    -draw "line 40,40 52,52" \
    "$ICON_DIR/search.png"
echo "✓ search.png"

# 筛选图标
convert -size ${SIZE}x${SIZE} xc:transparent \
    -fill "#6B7280" \
    -draw "rectangle 12,16 52,20" \
    -draw "rectangle 18,28 46,32" \
    -draw "rectangle 24,40 40,44" \
    "$ICON_DIR/filter.png"
echo "✓ filter.png"

# 返回图标
convert -size ${SIZE}x${SIZE} xc:transparent \
    -fill "none" -stroke "#374151" -strokewidth 4 \
    -draw "path 'M 40,12 L 20,32 L 40,52'" \
    "$ICON_DIR/back.png"
echo "✓ back.png"

# 时钟图标
convert -size ${SIZE}x${SIZE} xc:transparent \
    -fill "none" -stroke "#6B7280" -strokewidth 3 \
    -draw "circle 32,32 32,8" \
    -draw "line 32,32 32,18" \
    -draw "line 32,32 44,32" \
    "$ICON_DIR/clock.png"
echo "✓ clock.png"

# 历史记录图标
convert -size ${SIZE}x${SIZE} xc:transparent \
    -fill "none" -stroke "#6B7280" -strokewidth 3 \
    -draw "circle 32,32 32,8" \
    -draw "line 32,32 32,18" \
    -draw "line 32,32 44,32" \
    -draw "path 'M 12,32 Q 12,12 32,12'" \
    -draw "polygon 8,20 16,12 16,28" \
    "$ICON_DIR/history.png"
echo "✓ history.png"

# 位置图标
convert -size ${SIZE}x${SIZE} xc:transparent \
    -fill "#3B82F6" -draw "circle 32,26 32,10" \
    -fill "#3B82F6" -draw "polygon 32,54 18,30 46,30" \
    -fill "white" -draw "circle 32,26 32,18" \
    -fill "#3B82F6" -draw "circle 32,26 32,22" \
    "$ICON_DIR/location.png"
echo "✓ location.png"

# 位置图钉图标
convert -size ${SIZE}x${SIZE} xc:transparent \
    -fill "#EF4444" -draw "circle 32,24 32,8" \
    -fill "#EF4444" -draw "polygon 32,52 20,28 44,28" \
    -fill "white" -draw "circle 32,24 32,16" \
    "$ICON_DIR/location-pin.png"
echo "✓ location-pin.png"

# 闪电图标 (充电中)
convert -size ${SIZE}x${SIZE} xc:transparent \
    -fill "#F59E0B" \
    -draw "polygon 36,8 16,36 28,36 24,56 48,28 36,28" \
    "$ICON_DIR/lightning.png"
echo "✓ lightning.png"

echo ""
echo "所有图标生成完成！共 $(ls -1 $ICON_DIR/*.png | wc -l) 个图标"
echo "位置: $ICON_DIR"
