#!/usr/bin/env python3
"""
测试 Nav2 发目标：从 TF 取当前位姿，在正前方 1m 发一个目标，并打印结果/错误。
用法: cd navi && source install/setup.bash && python3 scripts/send_nav2_goal_test.py
"""
import rclpy
from rclpy.node import Node
from rclpy.action import ActionClient
from geometry_msgs.msg import PoseStamped
from nav2_msgs.action import NavigateToPose
from tf2_ros import Buffer, TransformListener
from tf2_ros import TransformException
import math


def main():
    rclpy.init()
    node = Node("send_nav2_goal_test")
    buffer = Buffer()
    listener = TransformListener(buffer, node)

    # 等 map -> base_link
    node.get_logger().info("等待 TF map -> base_link ...")
    try:
        t = buffer.lookup_transform(
            "map", "base_link", rclpy.time.Time(), rclpy.duration.Duration(seconds=5.0)
        )
    except TransformException as e:
        node.get_logger().error("TF 失败: %s" % str(e))
        node.destroy_node()
        rclpy.shutdown()
        return

    x = t.transform.translation.x
    y = t.transform.translation.y
    # 从 quaternion 取 yaw（简化）
    q = t.transform.rotation
    yaw = math.atan2(
        2.0 * (q.w * q.z + q.x * q.y), 1.0 - 2.0 * (q.y * q.y + q.z * q.z)
    )
    node.get_logger().info("当前位姿 (map): x=%.2f y=%.2f yaw=%.2f" % (x, y, yaw))

    # 目标：正前方 1m
    goal_x = x + math.cos(yaw) * 1.0
    goal_y = y + math.sin(yaw) * 1.0

    goal_msg = NavigateToPose.Goal()
    goal_msg.pose = PoseStamped()
    goal_msg.pose.header.frame_id = "map"
    goal_msg.pose.header.stamp = node.get_clock().now().to_msg()
    goal_msg.pose.pose.position.x = goal_x
    goal_msg.pose.pose.position.y = goal_y
    goal_msg.pose.pose.position.z = 0.0
    goal_msg.pose.pose.orientation.x = 0.0
    goal_msg.pose.pose.orientation.y = 0.0
    goal_msg.pose.pose.orientation.z = math.sin(yaw / 2.0)
    goal_msg.pose.pose.orientation.w = math.cos(yaw / 2.0)

    client = ActionClient(node, NavigateToPose, "navigate_to_pose")
    node.get_logger().info("等待 navigate_to_pose 动作服务...")
    if not client.wait_for_server(timeout_sec=5.0):
        node.get_logger().error("navigate_to_pose 服务不可用")
        node.destroy_node()
        rclpy.shutdown()
        return

    node.get_logger().info("发送目标 (%.2f, %.2f) ..." % (goal_x, goal_y))
    send_future = client.send_goal_async(goal_msg)
    rclpy.spin_until_future_complete(node, send_future, timeout_sec=2.0)
    if not send_future.result().accepted:
        node.get_logger().error("目标被拒绝: %s" % send_future.result().message)
        node.destroy_node()
        rclpy.shutdown()
        return

    result_future = send_future.result().get_result_async()
    node.get_logger().info("等待导航结果（最多 60s）...")
    rclpy.spin_until_future_complete(node, result_future, timeout_sec=60.0)
    if result_future.done():
        res = result_future.result().result
        node.get_logger().info(
            "结果: code=%s, 消息=%s" % (res.error_code, res.message or "(无)")
        )
        if res.error_code != 0:
            node.get_logger().warn("若为 4 常为超时/未到达，若为 3 常为规划失败")
    else:
        node.get_logger().warn("等待结果超时")

    node.destroy_node()
    rclpy.shutdown()


if __name__ == "__main__":
    main()
