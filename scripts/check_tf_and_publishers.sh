#!/bin/bash
# 在程序运行时执行，检查 TF 与多发布者是否导致抖动
# 用法: source navi/install/setup.bash && ./navi/scripts/check_tf_and_publishers.sh

set -e
echo "========== 1. /tf 发布者数量（若 >1 个发布者可能冲突）=========="
ros2 topic info /tf --verbose 2>/dev/null || true
echo ""
echo "========== 2. /tf_static 发布者数量 =========="
ros2 topic info /tf_static --verbose 2>/dev/null || true
echo ""
echo "========== 3. TF 监控（看 authority 与 delay，异常会标出）=========="
timeout 5 ros2 run tf2_ros tf2_monitor 2>/dev/null || true
echo ""
echo "========== 4. 关键 frame 的 TF 关系（odom->base_link, map->odom）=========="
echo "--- 最近一条 odom -> base_link ---"
timeout 2 ros2 run tf2_ros tf2_echo odom base_link 2>/dev/null | head -20 || echo "（无或超时）"
echo "--- 最近一条 map -> odom ---"
timeout 2 ros2 run tf2_ros tf2_echo map odom 2>/dev/null | head -20 || echo "（无或超时）"
echo ""
echo "========== 5. 发布 /tf 的节点 =========="
ros2 topic info /tf 2>/dev/null | grep -A 100 "Publisher count" || true
echo ""
echo "========== 6. 发布 /odom 或 /rgbd_odometry/odom 的节点 =========="
for t in /odom /rgbd_odometry/odom; do
  if ros2 topic list | grep -q "^${t}$"; then
    echo "Topic: $t"
    ros2 topic info "$t" 2>/dev/null || true
  fi
done
echo ""
echo "检查完成。若 /tf 有多个 Publisher 或 tf2_monitor 报 Multiple authority，说明存在多发布者冲突。"
