from pathlib import Path

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.conditions import IfCondition
from launch.substitutions import Command, FindExecutable, LaunchConfiguration
from launch_ros.parameter_descriptions import ParameterValue
from launch_ros.actions import Node


def generate_launch_description():
    pkg_share = Path(get_package_share_directory("brace"))

    default_model = str(pkg_share / "urdf" / "brace.urdf")
    default_rviz = str(pkg_share / "rviz" / "brace.rviz")

    model_arg = DeclareLaunchArgument(
        "model",
        default_value=default_model,
        description="Absolute path to robot URDF file.",
    )
    use_gui_arg = DeclareLaunchArgument(
        "use_gui",
        default_value="true",
        description="Start joint_state_publisher_gui.",
    )
    use_rviz_arg = DeclareLaunchArgument(
        "use_rviz",
        default_value="true",
        description="Start rviz2.",
    )
    rvizconfig_arg = DeclareLaunchArgument(
        "rvizconfig",
        default_value=default_rviz,
        description="Absolute path to rviz config file.",
    )

    model_path = LaunchConfiguration("model")
    use_gui = LaunchConfiguration("use_gui")
    use_rviz = LaunchConfiguration("use_rviz")
    rvizconfig = LaunchConfiguration("rvizconfig")

    robot_description = ParameterValue(
        Command([FindExecutable(name="cat"), " ", model_path]),
        value_type=str,
    )

    robot_state_publisher_node = Node(
        package="robot_state_publisher",
        executable="robot_state_publisher",
        output="screen",
        parameters=[{"robot_description": robot_description}],
    )

    joint_state_publisher_gui_node = Node(
        package="joint_state_publisher_gui",
        executable="joint_state_publisher_gui",
        output="screen",
        condition=IfCondition(use_gui),
    )

    rviz_node = Node(
        package="rviz2",
        executable="rviz2",
        output="screen",
        arguments=["-d", rvizconfig],
        condition=IfCondition(use_rviz),
    )

    return LaunchDescription(
        [
            model_arg,
            use_gui_arg,
            use_rviz_arg,
            rvizconfig_arg,
            robot_state_publisher_node,
            joint_state_publisher_gui_node,
            rviz_node,
        ]
    )
