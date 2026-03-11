#!/bin/bash
# 定位模式下“发目标无路径、机器人不动”时运行此脚本排查并尝试修复
# 用法: cd navi && source install/setup.bash && ./scripts/nav2_loc_diagnostics.sh

set -e
echo "========== 1. 检查 /map 是否有人发布 =========="
ros2 topic info /map 2>/dev/null || { echo "/map 无发布者，Nav2 无法规划。"; }
echo ""
echo "========== 2. 强制 rtabmap 发布一次 /map（供 Nav2 使用）=========="
if ros2 service list | grep -q /rtabmap/publish_map; then
  ros2 service call /rtabmap/publish_map rtabmap_msgs/srv/PublishMap "{global_map: true, optimized: true, graph_only: false}" 2>/dev/null && echo "已调用 publish_map。" || echo "调用失败（可能 rtabmap 未就绪）。"
else
  echo "未找到 /rtabmap/publish_map，请确认已启动 brace_realsense_nav 且 localization:=true。"
fi
echo ""
echo "========== 3. 检查 Nav2 动作与生命周期 =========="
ros2 action list 2>/dev/null | grep -E "navigate|Navigate" || true
echo "--- 若上面有 /navigate_to_pose，说明 bt_navigator 在运行 ---"
ros2 lifecycle get /controller_server 2>/dev/null || echo "controller_server 未找到或未就绪"
ros2 lifecycle get /planner_server 2>/dev/null || echo "planner_server 未找到或未就绪"
echo ""
echo "========== 4. 检查 /plan 与 /cmd_vel =========="
echo "规划结果话题 /plan 的订阅者（应有 controller）："
ros2 topic info /plan 2>/dev/null || true
echo "底盘速度话题 /cmd_vel 的发布者（应有 controller_server 或 velocity_smoother）："
ros2 topic info /cmd_vel 2>/dev/null || true
echo ""
echo "========== 5. 建议 =========="
echo "1) 若 /map 无发布者：先执行步骤 2 后等几秒，再在 RViz 里重新发目标。"
echo "2) 若 planner/controller 不是 active：检查 Nav2 启动日志是否有 TF 超时。"
echo "3) 目标点请选在已建图区域、且不在障碍物上；Fixed Frame 为 map。"
