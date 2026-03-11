#!/bin/bash
# 从 rtabmap 的 .db 文件导出 2D 栅格地图（pgm + yaml），供 RViz/Nav2 使用或人工检查
# 用法:
#   cd navi && source install/setup.bash && ./scripts/export_map_from_db.sh
#   ./scripts/export_map_from_db.sh /path/to/other.db
#   ./scripts/export_map_from_db.sh /path/to/other.db /out
# 若觉得地图不准，可先重新优化再导出: EXPORT_MAP_OPT=0 ./scripts/export_map_from_db.sh

set -e
DB="${1:-/home/brace/maps/map.db}"
OUT_DIR="${2:-$(dirname "$DB")}"
NAME=$(basename "$DB" .db)

if [[ ! -f "$DB" ]]; then
  echo "数据库不存在: $DB"
  exit 1
fi
mkdir -p "$OUT_DIR"

echo "数据库: $DB"
echo "输出目录: $OUT_DIR"
echo ""

# --map: 导出 2D 栅格
# --opt 2: 使用 db 里已保存的优化结果和已保存的 2D 图（最快，和建图时一致）
# --opt 0: 重新做全局优化并重新拼 2D 图（更慢，有时更准）
OPT="${EXPORT_MAP_OPT:-2}"
if [[ "$OPT" == "0" ]]; then
  echo "使用 --opt 0：重新优化并拼图（较慢，可能更准）..."
else
  echo "使用 --opt 2：直接导出 db 内已保存的 2D 图..."
fi

rtabmap-export --map --opt "$OPT" --output "$NAME" --output_dir "$OUT_DIR" "$DB"

echo ""
echo "导出完成: $OUT_DIR/${NAME}.pgm 与 $OUT_DIR/${NAME}.yaml"
echo ""
echo "========== 导出后如何使用 =========="
echo "1) 用 map_server 发布该地图（单独终端，先起再起定位）："
echo "   ros2 run nav2_map_server map_server --ros-args -p yaml_filename:=$OUT_DIR/${NAME}.yaml"
echo "2) 再起底盘 + 定位（同目录下 db 不变）："
echo "   终端1: ros2 launch brace_bot brace_bot_bringup.launch.py"
echo "   终端2: ros2 launch rtabmap_examples brace_realsense_nav.launch.py localization:=true database_path:=$DB rviz:=true"
echo "   Nav2 会使用 map_server 的 /map，无需再调 rtabmap 的 publish_map。"
echo "3) 仅在 RViz 看图：启动 map_server 后，在 RViz 添加 Map，Topic 填 /map。"
