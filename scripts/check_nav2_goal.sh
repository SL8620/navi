#!/bin/bash
# 发目标时检查是否有规划与速度：先运行此脚本，再在 RViz 里点一次 Nav2 Goal，看是否有输出
# 用法: cd navi && source install/setup.bash && ./scripts/check_nav2_goal.sh

set -e
echo "请在 15 秒内到 RViz 里点击工具栏的 'Nav2 Goal'，在地图上点一个目标点。"
echo "下面会监听 /plan 和 /cmd_vel，收到数据会打印。"
echo "若无反应：确认已添加 Nav2 面板（Panels -> Add by Name -> Nav2），否则点 Goal 不会真正发目标。"
echo ""

# 后台收 /plan 和 /cmd_vel，收到即打印
( timeout 15 ros2 topic echo /plan --once 2>/dev/null && echo "[OK] /plan 收到一条规划" ) &
( timeout 15 ros2 topic echo /cmd_vel --once 2>/dev/null && echo "[OK] /cmd_vel 收到一条速度" ) &

wait -n 2>/dev/null || true
sleep 2
echo ""
echo "若上面没有 [OK]："
echo "  1) 确认 RViz 已加载带 Nav2 面板的配置（brace_nav.rviz），或手动添加 Panels -> Nav2。"
echo "  2) 确认 Fixed Frame = map，目标点在已建图可通行区域。"
echo "  3) 看终端里 Nav2/bt_navigator 是否有报错（goal aborted / failed to plan）。"
echo "  4) 若用 rtabmap 定位，先确保 map_server 已激活且做过 2D Pose Estimate。"
