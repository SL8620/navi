#!/bin/bash
# 启动导航：使用处理过的静态地图 rtabmap00

# 1. 启动 Realsense 相机
gnome-terminal -- bash -c "source /home/brace/navi/install/setup.bash && ros2 launch realsense2_camera rs_launch.py align_depth:=true depth_module.enable_publisher:=true; exec bash" &

sleep 3

# 2. 启动 RTAB-Map 定位模式（使用已有数据库）
gnome-terminal -- bash -c "source /home/brace/navi/install/setup.bash && ros2 launch rtabmap_examples realsense_d435i_color_localization.launch.py database_path:=/home/brace/.ros/rtabmap.db; exec bash" &

sleep 3

# 3. 启动地图服务器（发布处理过的静态地图）
gnome-terminal -- bash -c "source /home/brace/navi/install/setup.bash && ros2 run nav2_map_server map_server --ros-args -p yaml_filename:=/home/brace/maps/rtabmap00.yaml; exec bash" &

sleep 2

# 4. 启动 Nav2 导航
gnome-terminal -- bash -c "source /home/brace/navi/install/setup.bash && ros2 launch nav2_bringup navigation_launch.py params_file:=/home/brace/navi/config/nav2_realsense_rtabmap_params.yaml; exec bash" &

sleep 2

# 5. 启动 RViz 可视化
gnome-terminal -- bash -c "source /home/brace/navi/install/setup.bash && ros2 launch nav2_bringup rviz_launch.py; exec bash" &

echo "所有节点已启动！"
