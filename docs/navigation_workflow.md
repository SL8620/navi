# ROS2 Navigation 完整工作流程

## 系统架构

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Realsense     │────▶│    RTAB-Map     │────▶│   map_server    │
│   相机节点       │     │   SLAM 节点     │     │   地图服务器     │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                                        │
                                                        ▼
                                                ┌─────────────────┐
                                                │     Nav2        │
                                                │  导航堆栈        │
                                                │  (planner/      │
                                                │   controller)   │
                                                └─────────────────┘
                                                        │
                                                        ▼
                                                ┌─────────────────┐
                                                │     RViz2       │
                                                │   可视化界面     │
                                                └─────────────────┘
```

---

## 启动流程

```

### 2. 启动 RTAB-Map

```bash
source /home/brace/navi/install/setup.bash
ros2 launch rtabmap_demos realsense_stereo.launch.py
```

**参数说明：**
- `rgb/image` → RGB 图像话题
- `depth/image` → 深度图像话题
- `camera/info` → 相机内参话题
- `odom` → 里程计话题

### 3. 启动 map_server（发布优化后的地图）

```bash
source /home/brace/navi/install/setup.bash
ros2 launch nav2_map_server map_server_launch.py \
    yaml_filename:=/home/brace/maps/rtabmap00.yaml \
    map_topic:=/static_map
```

**注意：** map_server 是 lifecycle node，启动后需要激活。

**手动激活方法：**

在新终端运行：
```bash
ros2 service call /map_server/change_state lifecycle_msgs/srv/ChangeState "{transition: {id: 1}}"  # configure
ros2 service call /map_server/change_state lifecycle_msgs/srv/ChangeState "{transition: {id: 3}}"    # activate
```

**自动激活方法：**
```bash
ros2 run nav2_map_server map_server --ros-args \
    -p yaml_filename:=/home/brace/maps/rtabmap00.yaml \
    -r /map:=/static_map \
    -p autostart:=True
```

### 4. 启动 Nav2 导航堆栈

```bash
source /home/brace/navi/install/setup.bash
ros2 launch nav2_bringup navigation_launch.py \
    params_file:=/home/brace/navi/config/nav2_realsense_rtabmap_params.yaml
```

### 5. RViz2 可视化

```bash
source /home/brace/navi/install/setup.bash
rviz2 -d /home/brace/navi/config/nav2_default_cfg.rviz
```

**添加显示项：**
- `Map` → Topic: `/static_map`
- `RobotModel`
- `TF`
- `LaserScan` → Topic: `/scan`
- `Image` → Topic: `/depth/image_rect_raw`（可选）

---

## 参数配置

### Nav2 参数文件

路径：`/home/brace/navi/config/nav2_realsense_rtabmap_params.yaml`

**关键配置：**

```yaml
amcl:
  ros__parameters:
    use_sim_time: False
    alpha1: 0.2
    alpha2: 0.2
    alpha3: 0.2
    alpha4: 0.2
    alpha5: 0.2

controller_server:
  ros__parameters:
    use_sim_time: False
    controller_frequency: 20.0
    min_x_velocity_threshold: 0.001
    min_y_velocity_threshold: 0.001
    min_theta_velocity_threshold: 0.001

local_costmap:
  local_costmap:
    ros__parameters:
      use_sim_time: False
      global_frame: odom
      robot_base_frame: base_link
      update_frequency: 5.0
      publish_frequency: 2.0
      width: 3
      height: 3
      resolution: 0.05
      plugins: ["voxel_layer", "inflation_layer"]
      voxel_layer:
        plugin: "nav2_costmap_2d::VoxelLayer"
        enabled: True
        publish_voxel_map: true
        origin_z: 0.0
        z_resolution: 0.05
        z_voxels: 16
        max_obstacle_height: 2.0
        mark_threshold: 0
        observation_sources: scan
        scan:
          sensor_frame: link_realsense_depth
          topic: /scan
          marking: true
          clearing: true
          min_obstacle_height: 0.25
          max_obstacle_height: 2.0

global_costmap:
  global_costmap:
    ros__parameters:
      use_sim_time: False
      global_frame: map
      robot_base_frame: base_link
      update_frequency: 1.0
      publish_frequency: 1.0
      width: 20
      height: 20
      resolution: 0.05
      origin_x: -10.0
      origin_y: -10.0
      plugins: ["static_layer", "inflation_layer"]
      static_layer:
        plugin: "nav2_costmap_2d::StaticLayer"
        map_subscribe_transient_local: True
        map_topic: "/static_map"
      inflation_layer:
        plugin: "nav2_costmap_2d::InflationLayer"
        cost_scaling_factor: 3.0
        inflation_radius: 0.55

planner_server:
  ros__parameters:
    use_sim_time: False
    expected_planner_frequency: 20.0
```

---

## 常见问题与解决

### 1. map_server 一直卡在 "Waiting on external lifecycle transitions"

**原因：** lifecycle node 需要手动激活。

**解决方法：**
```bash
ros2 service call /map_server/change_state lifecycle_msgs/srv/ChangeState "{transition: {id: 1}}"
ros2 service call /map_server/change_state lifecycle_msgs/srv/ChangeState "{transition: {id: 3}}"
```

或使用 `--autostart` 参数：
```bash
ros2 run nav2_map_server map_server --ros-args -p autostart:=True ...
```

### 2. "Robot is out of bounds of the costmap!"

**原因：**
- 全局代价地图范围太小
- 机器人初始位置未设置

**解决方法：**
1. 在 RViz 中点击 `2D Pose Estimate` 设置机器人初始位置
2. 增大 global_costmap 的 `width` 和 `height`
3. 调整 `origin_x` 和 `origin_y` 匹配地图

### 3. 地图话题不匹配

**问题：** map_server 发布 `/map`，但 costmap 订阅 `/static_map`

**解决方法：** 使用 remap
```bash
-r /map:=/static_map
```

### 4. RTPS_TRANSPORT_SHM Error

```
[RTPS_TRANSPORT_SHM Error] Failed init_port fastrtps_port7439: open_and_lock_file failed
```

**原因：** 共享内存通信失败，通常不影响功能。

**解决方法：**
```bash
sudo rm -rf /dev/shm/*
```

或在 DDS 配置中禁用共享内存传输。

---

## 停止所有进程

```bash
# 方法 1：逐个终端 Ctrl+C

# 方法 2：一键清理
pkill -f "ros2"
ros2 cleanup
```

---

## 话题映射关系

| 组件 | 发布话题 | 订阅话题 |
|------|---------|---------|
| Realsense | `/depth/image_rect_raw`, `/color/image_raw`, `/camera_info` | - |
| RTAB-Map | `/map`, `/odom`, `/cloud_map` | `/rgb/image`, `/depth/image`, `/camera/info` |
| map_server | `/static_map` | - |
| Nav2 | `/cmd_vel` | `/static_map`, `/scan`, `/odom` |

---

## 生命周期状态转换

```
     [Unconfigured] ──configure──▶ [Inactive] ──activate──▶ [Active]
           ▲                              │                      │
           │                              │                      │
           └────────── cleanup ───────────┴──── deactivate ──────┘
```

| ID | 转换名称 | 描述 |
|----|---------|------|
| 0 | configure | 配置节点 |
| 1 | cleanup | 清理资源 |
| 3 | activate | 激活节点 |
| 4 | deactivate | 停用节点 |
| 5 | unconfigure_shutdown | 关闭并取消配置 |
| 6 | shutdown | 完全关闭 |

---

## 参考资料

- [ROS2 生命周期节点](https://design.ros2.org/articles/node_lifecycle.html)
- [Nav2 官方文档](https://navigation.ros.org/)
- [RTAB-Map ROS2](https://github.com/introlab/rtabmap_ros)


source /home/brace/navi/install/setup.bash && ros2 launch rtabmap_examples realsense_d435i_color_localization.launch.py database_path:=/home/brace/.ros/rtabmap.db

ros2 run nav2_map_server map_server --ros-args -p yaml_filename:=/home/brace/maps/rtabmap00.yaml -r /map:=/static_map

ros2 service call /map_server/change_state lifecycle_msgs/srv/ChangeState "{transition: {id: 3}}"  # activate


ros2 launch nav2_bringup navigation_launch.py params_file:=/home/brace/navi/config/nav2_realsense_rtabmap_params.yaml

source /home/brace/navi/install/setup.bash && ros2 launch nav2_bringup rviz_launch.py