import os

from ament_index_python.packages import get_package_share_directory

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription
from launch.substitutions import LaunchConfiguration

from launch_ros.actions import Node
from launch.launch_description_sources import PythonLaunchDescriptionSource


def generate_launch_description():

    parameters = [{

        # TF
        'frame_id': 'camera_link',

        # subscriptions
        'subscribe_depth': True,
        'subscribe_odom_info': True,

        # sync RGBD
        'approx_sync': True,

        # wait IMU
        'wait_imu_to_init': True,

        # Depth filtering
        'Depth/MinDepth': 0.20,
        'Depth/MaxDepth': 3.0,

        # Occupancy grid from depth
        'Grid/FromDepth': True,

        # map resolution
        'Grid/CellSize': 0.05,

        # sensing range
        'Grid/RangeMax': 3.0,

        # low camera filtering (camera height ≈5cm)
        'Grid/MinGroundHeight': -0.02,
        'Grid/MaxObstacleHeight': 0.35,

        'Grid/NormalsSegmentation': True,
        'Grid/GroundNormalsUp': 0.9,

        # noise filtering
        'Grid/ClusterRadius': 0.1,
        'Grid/MinClusterSize': 20,

        # SLAM tuning
        'RGBD/OptimizeFromGraphEnd': True,
        'RGBD/LoopClosureReextractFeatures': True,

        'Mem/IncrementalMemory': True,
        'Mem/InitWMWithAllNodes': False

    }]


    remappings = [

        ('imu', '/imu/data'),

        ('rgb/image', '/camera/color/image_raw'),
        ('rgb/camera_info', '/camera/color/camera_info'),

        ('depth/image', '/camera/aligned_depth_to_color/image_raw')

    ]


    return LaunchDescription([

        DeclareLaunchArgument(
            'unite_imu_method',
            default_value='2',
            description='0-none 1-copy 2-interpolation'
        ),


        # ===== RealSense camera =====
        IncludeLaunchDescription(
            PythonLaunchDescriptionSource(
                os.path.join(
                    get_package_share_directory('realsense2_camera'),
                    'launch',
                    'rs_launch.py'
                )
            ),
            launch_arguments={

                'camera_namespace': '',

                'enable_gyro': 'true',
                'enable_accel': 'true',

                'unite_imu_method': LaunchConfiguration('unite_imu_method'),

                'align_depth.enable': 'true',
                'enable_sync': 'true',

                'rgb_camera.profile': '640x360x30',
                'depth_module.profile': '640x360x30',

                # enable IR emitter
                'depth_module.emitter_enabled': '1'

            }.items(),
        ),


        # ===== camera TF =====
        # camera mounted 5cm above base_link and facing backwards
        Node(
            package='tf2_ros',
            executable='static_transform_publisher',
            arguments=[
                '0', '0', '0.05',
                '0', '0', '3.14159',
                'base_link',
                'camera_link'
            ]
        ),


        # ===== RGBD Odometry =====
        Node(
            package='rtabmap_odom',
            executable='rgbd_odometry',
            output='screen',
            parameters=parameters,
            remappings=remappings
        ),


        # ===== RTABMap SLAM =====
        Node(
            package='rtabmap_slam',
            executable='rtabmap',
            output='screen',
            parameters=parameters,
            remappings=remappings,
            arguments=['-d']
        ),


        # ===== RTABMap Visualization =====
        Node(
            package='rtabmap_viz',
            executable='rtabmap_viz',
            output='screen',
            parameters=parameters,
            remappings=remappings
        ),


        # ===== IMU filter =====
        Node(
            package='imu_filter_madgwick',
            executable='imu_filter_madgwick_node',
            output='screen',
            parameters=[{
                'use_mag': False,
                'world_frame': 'enu',
                'publish_tf': False
            }],
            remappings=[
                ('imu/data_raw', '/camera/imu')
            ]
        )

    ])