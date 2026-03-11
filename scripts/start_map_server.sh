#!/bin/bash
# 启动 map_server 并自动 configure + activate（解决“卡在 Creating”）
# 用法: ./scripts/start_map_server.sh
#       ./scripts/start_map_server.sh /path/to/map.yaml

YAML="${1:-/home/brace/maps/map_new.yaml}"
if [[ ! -f "$YAML" ]]; then
  echo "地图文件不存在: $YAML"
  exit 1
fi

echo "启动 map_server: yaml=$YAML"
echo "启动后 3 秒会执行 lifecycle configure + activate ..."
echo ""

# 后台启动 map_server
ros2 run nav2_map_server map_server --ros-args -p yaml_filename:="$YAML" &
PID=$!
sleep 3

# 激活生命周期
echo "执行: ros2 lifecycle set /map_server configure"
ros2 lifecycle set /map_server configure 2>/dev/null || true
sleep 0.5
echo "执行: ros2 lifecycle set /map_server activate"
ros2 lifecycle set /map_server activate 2>/dev/null || true

echo ""
echo "若上面两行无报错，/map 已在发布。map_server 在前台继续运行（Ctrl+C 退出）。"
wait $PID
