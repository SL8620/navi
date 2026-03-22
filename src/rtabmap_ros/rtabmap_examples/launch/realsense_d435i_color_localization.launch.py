# Requirements:
#   A realsense D435i
#   Install realsense2 ros2 package (ros-$ROS_DISTRO-realsense2-camera)
#
# Example:
#   $ ros2 launch rtabmap_examples realsense_d435i_color_localization.launch.py
#   $ ros2 launch rtabmap_examples realsense_d435i_color_localization.launch.py database_path:=/home/brace/maps/office.db

import os

from ament_index_python.packages import get_package_share_directory

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node, SetParameter


def generate_launch_description():
    parameters = [
        {
            'frame_id': 'camera_link',
            'subscribe_depth': True,
            'subscribe_odom_info': True,
            'approx_sync': False,
            'wait_imu_to_init': True,
            # Localization mode (do not add new nodes to the map)
            # These parameters are declared as string type in rtabmap_ros.
            'Mem/IncrementalMemory': 'false',
            'Mem/InitWMWithAllNodes': 'true',
            # Make sure TF map->odom is published
            'publish_tf': True,
            # Load existing map database
            'database_path': LaunchConfiguration('database_path'),
        }
    ]

    remappings = [
        # Use a dedicated odom topic to avoid conflicts with wheel odometry
        # (some platforms also publish /odom from diff controllers).
        ('odom', '/rgbd_odometry/odom'),
        ('imu', '/imu/data'),
        ('rgb/image', '/camera/color/image_raw'),
        ('rgb/camera_info', '/camera/color/camera_info'),
        ('depth/image', '/camera/aligned_depth_to_color/image_raw'),
    ]

    return LaunchDescription(
        [
            DeclareLaunchArgument(
                'database_path',
                default_value='/home/brace/maps/office.db',
                description='Path to the RTAB-Map database to load for localization.',
            ),
            DeclareLaunchArgument(
                'unite_imu_method',
                default_value='2',
                description='0-None, 1-copy, 2-linear_interpolation. Use unite_imu_method:="1" if imu topics stop being published.',
            ),
            # Make sure IR emitter is enabled (better depth indoors)
            SetParameter(name='depth_module.emitter_enabled', value=1),
            # Launch camera driver
            IncludeLaunchDescription(
                PythonLaunchDescriptionSource(
                    [
                        os.path.join(get_package_share_directory('realsense2_camera'), 'launch'),
                        '/rs_launch.py',
                    ]
                ),
                launch_arguments={
                    'camera_namespace': '',
                    'enable_gyro': 'true',
                    'enable_accel': 'true',
                    'unite_imu_method': LaunchConfiguration('unite_imu_method'),
                    'align_depth.enable': 'true',
                    'enable_sync': 'true',
                    'rgb_camera.profile': '640x360x30',
                }.items(),
            ),
            # RGB-D odometry
            Node(
                package='rtabmap_odom',
                executable='rgbd_odometry',
                output='screen',
                parameters=parameters,
                remappings=remappings,
            ),
            # RTAB-Map localization (no '-d' here, to avoid deleting the database)
            Node(
                package='rtabmap_slam',
                executable='rtabmap',
                output='screen',
                parameters=parameters,
                remappings=remappings,
            ),
            Node(
                package='rtabmap_viz',
                executable='rtabmap_viz',
                output='screen',
                parameters=parameters,
                remappings=remappings,
            ),
            # Compute quaternion of the IMU: /camera/imu -> /imu/data
            Node(
                package='imu_filter_madgwick',
                executable='imu_filter_madgwick_node',
                output='screen',
                parameters=[
                    {
                        'use_mag': False,
                        'world_frame': 'enu',
                        'publish_tf': False,
                    }
                ],
                remappings=[('imu/data_raw', '/camera/imu')],
            ),
        ]
    )
