#!/bin/bash
# 自动运行建图/导航并抓日志
# 用法:
#   ./navi/scripts/run_and_log.sh           # 仅启动 nav，日志到 navi/logs/<时间戳>/
#   ./navi/scripts/run_and_log.sh all      # 先后台启动 bringup，再启动 nav，两者日志都抓

set -e
CODE_SPACE="${CODE_SPACE:-/home/brace/codeSpace}"
NAVI_WS="${CODE_SPACE}/navi"
BRACE_WS="${CODE_SPACE}/BraceRobot"
LOG_ROOT="${NAVI_WS}/logs"
STAMP=$(date +%Y-%m-%d_%H-%M-%S)
LOG_DIR="${LOG_ROOT}/${STAMP}"
BRINGUP_PID=""

mkdir -p "$LOG_DIR"
echo "日志目录: $LOG_DIR"

cleanup() {
  if [[ -n "$BRINGUP_PID" ]] && kill -0 "$BRINGUP_PID" 2>/dev/null; then
    echo "停止 bringup (pid $BRINGUP_PID)..."
    kill "$BRINGUP_PID" 2>/dev/null || true
    wait "$BRINGUP_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

run_bringup_background() {
  if [[ ! -d "$BRACE_WS/install" ]]; then
    echo "未找到 BraceRobot 工作空间: $BRACE_WS/install，跳过 bringup"
    return 0
  fi
  echo "后台启动 bringup，日志: $LOG_DIR/bringup.log"
  (
    source /opt/ros/humble/setup.bash 2>/dev/null || source /opt/ros/jazzy/setup.bash 2>/dev/null || true
    source "$BRACE_WS/install/setup.bash"
    ros2 launch brace_bot brace_bot_bringup.launch.py
  ) >> "$LOG_DIR/bringup.log" 2>&1 &
  BRINGUP_PID=$!
  echo "bringup pid: $BRINGUP_PID，等待 8 秒再启动 nav..."
  sleep 8
}

run_nav() {
  source /opt/ros/humble/setup.bash 2>/dev/null || source /opt/ros/jazzy/setup.bash 2>/dev/null || true
  source "$NAVI_WS/install/setup.bash"
  echo "启动 nav，日志: $LOG_DIR/nav.log（同时输出到终端）"
  ros2 launch rtabmap_examples brace_realsense_nav.launch.py 2>&1 | tee "$LOG_DIR/nav.log"
}

if [[ "${1:-}" == "all" ]]; then
  run_bringup_background
fi

run_nav
