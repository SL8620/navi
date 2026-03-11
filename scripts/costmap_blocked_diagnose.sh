#!/bin/bash
# 机器人被代价地图“堵死”时排查：看 /scan、depthimage_to_laserscan 参数、是否来自 static map
# 用法: cd navi && source install/setup.bash && ./scripts/costmap_blocked_diagnose.sh

set -e
echo "========== 1. depthimage_to_laserscan 当前参数（若与 launch 不符说明未重编或未生效）=========="
for p in scan_height range_min range_max; do
  v=$(ros2 param get /depthimage_to_laserscan $p 2>/dev/null) && echo "  $p: $v" || echo "  节点未运行或无 $p"
done
echo ""

echo "========== 2. /scan 一条消息的 range_min/range_max（应为上述 range_min 起）=========="
timeout 2 ros2 topic echo /scan --once 2>/dev/null | grep -E "range_min|range_max|angle_min|angle_max" || echo "  未收到 /scan"
echo ""

echo "========== 3. /scan 近距离点数（采样 1 条，统计 <0.6m 的点；多则说明地面/近处仍进 scan）=========="
TMP=$(mktemp)
timeout 2 ros2 topic echo /scan --once 2>/dev/null > "$TMP" || true
if grep -q "ranges:" "$TMP"; then
  sed -n '/^ranges:/,/^[a-z]/p' "$TMP" | grep -oE '[0-9]+\.?[0-9]*' | awk '
    BEGIN { n=0; near=0 }
    { n++; if ($1+0 < 0.6 && $1+0 > 0) near++ }
    END {
      if (n>0) {
        printf "  总点数约: %d, 其中 <0.6m: %d\n", n, near;
        if (near > n/4) print "  >>> 近距离点很多，易堵死。请把 range_min 提到 0.6~0.7 或检查 scan_height=1"
      } else print "  未解析到 ranges"
    }'
else
  echo "  未收到 /scan 或格式不同"
fi
rm -f "$TMP"
echo ""

echo "========== 4. local_costmap 的 plugins（含 voxel 则障碍来自 /scan）=========="
ros2 param get /local_costmap/local_costmap plugins 2>/dev/null || true
echo ""

echo "========== 5. /map 发布者（若用 map_server，global 障碍来自该图）=========="
ros2 topic info /map 2>/dev/null || true
echo ""

echo "========== 6. 建议 =========="
echo "· 堵死主要来自 local_costmap → 多为 /scan 近距离点：把 launch 里 range_min 提到 0.65 或 0.7，并确认 scan_height=1 后重编 rtabmap_examples 再试。"
echo "· 若改用 no_voxel 配置后不再堵死，可确认是 scan 导致；再用上面加大 range_min 解决。"
echo "· 堵死来自 global（整张图一圈墙）→ 多为 /map 里地面被标成障碍：用 db 重导地图或调 rtabmap Grid 再导出。"
