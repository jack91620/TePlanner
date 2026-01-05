#!/usr/bin/env python
"""Tesla Navigation Test Script.

This script tests the navigation functionality:
1. Get vehicle's current location
2. Accept destination input (address or coordinates)
3. Send navigation waypoints to the vehicle

Usage:
    # Interactive mode (reads token from .env)
    python tests/tesla/test_navigation.py

    # With explicit token
    python tests/tesla/test_navigation.py --token YOUR_ACCESS_TOKEN

    # Direct destination input
    python tests/tesla/test_navigation.py --destination "上海市浦东新区陆家嘴"

    # With GPS coordinates
    python tests/tesla/test_navigation.py --lat 31.2304 --lng 121.4737

    # Send two waypoints (intermediate + final destination)
    python tests/tesla/test_navigation.py --waypoint "南京路步行街" --destination "外滩"
"""

import argparse
import asyncio
import os
import sys
from pathlib import Path
from typing import Optional, Tuple

# Add project root to path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

# Load .env file
from dotenv import load_dotenv

load_dotenv(project_root / ".env")

from app.integrations.tesla.client import TeslaClient
from app.integrations.tesla.exceptions import TeslaAPIError
from app.integrations.tencent_map.client import TencentMapClient


class NavigationTester:
    """Navigation test helper class."""

    def __init__(self, tesla_token: str):
        """Initialize with Tesla access token."""
        self.tesla_token = tesla_token
        self.tesla_client: Optional[TeslaClient] = None
        self.map_client: Optional[TencentMapClient] = None
        self.vehicle_id: Optional[str] = None
        self.vehicle_name: Optional[str] = None

    async def __aenter__(self):
        """Async context manager entry."""
        self.tesla_client = TeslaClient(self.tesla_token)
        self.map_client = TencentMapClient()
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Async context manager exit."""
        if self.tesla_client:
            await self.tesla_client.close()
        if self.map_client:
            await self.map_client.close()

    async def select_vehicle(self, vehicle_id: Optional[str] = None) -> bool:
        """Select vehicle to use for testing.

        Args:
            vehicle_id: Optional specific vehicle ID

        Returns:
            True if vehicle selected successfully
        """
        print("\n" + "=" * 60)
        print("获取车辆列表...")
        print("=" * 60)

        try:
            result = await self.tesla_client.list_vehicles()
            vehicles = result.get("response", [])

            if not vehicles:
                print("错误: 未找到任何车辆")
                return False

            # Display available vehicles
            print(f"\n找到 {len(vehicles)} 辆车:")
            for i, v in enumerate(vehicles):
                print(f"  [{i + 1}] {v.get('display_name', 'Unknown')} (ID: {v.get('id')})")
                print(f"      VIN: {v.get('vin')}")
                print(f"      状态: {v.get('state')}")

            # Select vehicle
            if vehicle_id:
                self.vehicle_id = vehicle_id
            else:
                self.vehicle_id = str(vehicles[0].get("id"))
                self.vehicle_name = vehicles[0].get("display_name", "Unknown")

            print(f"\n已选择车辆: {self.vehicle_name} ({self.vehicle_id})")
            return True

        except TeslaAPIError as e:
            print(f"获取车辆列表失败: {e}")
            return False

    async def wake_vehicle(self, max_attempts: int = 10) -> bool:
        """Wake up the vehicle if needed.

        Args:
            max_attempts: Maximum wake up attempts

        Returns:
            True if vehicle is online
        """
        print("\n" + "-" * 40)
        print("唤醒车辆...")

        for attempt in range(max_attempts):
            try:
                print(f"  尝试 {attempt + 1}/{max_attempts}...")
                await self.tesla_client.ensure_vehicle_online(self.vehicle_id, max_attempts=3)
                print("车辆已在线!")
                return True
            except Exception as e:
                error_msg = str(e)
                if "429" in error_msg:
                    # Rate limited, extract wait time
                    import re
                    match = re.search(r"(\d+)\s*seconds?", error_msg)
                    wait_time = int(match.group(1)) if match else 35
                    print(f"  API 限流，等待 {wait_time} 秒...")
                    await asyncio.sleep(wait_time + 5)
                elif "408" in error_msg or "offline" in error_msg.lower():
                    print(f"  车辆离线，等待 10 秒后重试...")
                    await asyncio.sleep(10)
                else:
                    print(f"  错误: {e}")
                    if attempt < max_attempts - 1:
                        print(f"  等待 5 秒后重试...")
                        await asyncio.sleep(5)

        print("唤醒车辆失败: 已达最大重试次数")
        return False

    async def get_current_location(self) -> Optional[Tuple[float, float, str]]:
        """Get vehicle's current location.

        Returns:
            Tuple of (latitude, longitude, address) or None
        """
        print("\n" + "-" * 40)
        print("获取车辆当前位置...")

        try:
            drive_state = await self.tesla_client.get_drive_state(self.vehicle_id)

            lat = drive_state.get("latitude")
            lng = drive_state.get("longitude")
            heading = drive_state.get("heading")
            speed = drive_state.get("speed")

            if lat is None or lng is None:
                print("错误: 无法获取车辆位置")
                return None

            print(f"  纬度: {lat}")
            print(f"  经度: {lng}")
            print(f"  方向: {heading}°")
            print(f"  速度: {speed or 0} km/h")

            # Reverse geocode to get address
            address = "未知位置"
            try:
                geo_result = await self.map_client.reverse_geocode(lat, lng)
                address = geo_result.get("address", "未知位置")
                print(f"  地址: {address}")
            except Exception as e:
                print(f"  地址解析失败: {e}")

            return (lat, lng, address)

        except TeslaAPIError as e:
            print(f"获取位置失败: {e}")
            return None

    async def geocode_address(self, address: str) -> Optional[Tuple[float, float]]:
        """Convert address to coordinates.

        Args:
            address: Address string

        Returns:
            Tuple of (latitude, longitude) or None
        """
        print(f"\n解析地址: {address}")

        try:
            result = await self.map_client.geocode(address)
            location = result.get("location", {})
            lat = location.get("lat")
            lng = location.get("lng")

            if lat and lng:
                print(f"  坐标: ({lat}, {lng})")
                return (lat, lng)
            else:
                print("  错误: 无法解析该地址")
                return None

        except Exception as e:
            print(f"  地址解析失败: {e}")
            return None

    async def send_navigation(
        self,
        lat: float,
        lng: float,
        order: int = 1,
        description: str = "",
    ) -> bool:
        """Send navigation destination to vehicle.

        Args:
            lat: Destination latitude
            lng: Destination longitude
            order: Waypoint order (1 for first, 2 for second, etc.)
            description: Description for logging

        Returns:
            True if successful
        """
        print(f"\n发送导航目的地 #{order}: {description or f'({lat}, {lng})'}")

        try:
            result = await self.tesla_client.navigation_gps_request(
                self.vehicle_id,
                lat=lat,
                lon=lng,
                order=order,
            )

            response = result.get("response", {})
            success = response.get("result", False)

            if success:
                print(f"  成功! 导航已发送到车机")
            else:
                reason = response.get("reason", "未知原因")
                print(f"  失败: {reason}")

            return success

        except TeslaAPIError as e:
            print(f"  发送导航失败: {e}")
            return False

    async def send_navigation_address(
        self,
        address: str,
        locale: str = "zh-CN",
    ) -> bool:
        """Send navigation using address string.

        Args:
            address: Destination address
            locale: Locale for address parsing

        Returns:
            True if successful
        """
        print(f"\n发送地址导航: {address}")

        try:
            result = await self.tesla_client.navigation_request(
                self.vehicle_id,
                address=address,
                locale=locale,
            )

            response = result.get("response", {})
            success = response.get("result", False)

            if success:
                print(f"  成功! 导航已发送到车机")
            else:
                reason = response.get("reason", "未知原因")
                print(f"  失败: {reason}")

            return success

        except TeslaAPIError as e:
            print(f"  发送导航失败: {e}")
            return False


async def run_navigation_test(
    token: str,
    vehicle_id: Optional[str] = None,
    destination: Optional[str] = None,
    waypoint: Optional[str] = None,
    dest_lat: Optional[float] = None,
    dest_lng: Optional[float] = None,
    interactive: bool = True,
    direct_mode: bool = False,
):
    """Run the navigation test.

    Args:
        token: Tesla access token
        vehicle_id: Optional specific vehicle ID
        destination: Destination address
        waypoint: Optional intermediate waypoint address
        dest_lat: Destination latitude (if using coordinates)
        dest_lng: Destination longitude (if using coordinates)
        interactive: If True, prompt for input
        direct_mode: If True, send address directly to vehicle (skip geocoding)
    """
    print("\n" + "=" * 60)
    print("Tesla 导航测试脚本")
    print("=" * 60)
    if direct_mode:
        print("模式: 直接发送地址到车机")

    async with NavigationTester(token) as tester:
        # 1. Select vehicle
        if not await tester.select_vehicle(vehicle_id):
            return

        # 2. Wake vehicle
        if not await tester.wake_vehicle():
            return

        # 3. Get current location (skip geocoding in direct mode if map API fails)
        current_location = None
        try:
            current_location = await tester.get_current_location()
        except Exception as e:
            print(f"\n警告: 无法获取当前位置: {e}")

        if not current_location:
            print("\n警告: 无法获取当前位置，继续执行...")

        # Direct mode: send addresses directly to vehicle
        if direct_mode:
            addresses_to_send = []
            if waypoint:
                addresses_to_send.append(waypoint)
            if destination:
                addresses_to_send.append(destination)

            if not addresses_to_send and interactive:
                print("\n" + "-" * 40)
                print("请输入导航目的地 (直接发送模式):")
                user_input = input("目的地地址: ").strip()
                if user_input:
                    addresses_to_send.append(user_input)

            if not addresses_to_send:
                print("\n错误: 未指定任何目的地")
                return

            print("\n" + "=" * 60)
            print(f"直接发送 {len(addresses_to_send)} 个地址到车机")
            print("=" * 60)

            for addr in addresses_to_send:
                success = await tester.send_navigation_address(addr)
                if not success:
                    print(f"\n警告: 地址 '{addr}' 发送失败")

            print("\n" + "=" * 60)
            print("导航测试完成!")
            print("=" * 60)
            return

        # 4. Determine destination (with geocoding)
        destinations = []

        # Handle waypoint (intermediate stop)
        if waypoint:
            coords = await tester.geocode_address(waypoint)
            if coords:
                destinations.append((coords[0], coords[1], waypoint, 1))

        # Handle destination
        if dest_lat is not None and dest_lng is not None:
            # Direct coordinates
            order = 2 if waypoint else 1
            destinations.append((dest_lat, dest_lng, f"坐标 ({dest_lat}, {dest_lng})", order))
        elif destination:
            # Address string
            coords = await tester.geocode_address(destination)
            if coords:
                order = 2 if waypoint else 1
                destinations.append((coords[0], coords[1], destination, order))
        elif interactive:
            # Interactive mode - prompt for input
            print("\n" + "-" * 40)
            print("请输入导航目的地:")
            print("  1. 输入地址 (例如: 上海市浦东新区陆家嘴)")
            print("  2. 输入坐标 (格式: 纬度,经度)")
            print("  3. 输入 'q' 退出")

            while True:
                user_input = input("\n目的地: ").strip()

                if user_input.lower() == "q":
                    print("已退出")
                    return

                if not user_input:
                    continue

                # Check if it's coordinates
                if "," in user_input:
                    try:
                        parts = user_input.split(",")
                        lat = float(parts[0].strip())
                        lng = float(parts[1].strip())
                        order = len(destinations) + 1
                        destinations.append((lat, lng, f"坐标 ({lat}, {lng})", order))
                        print(f"已添加目的地 #{order}")
                    except ValueError:
                        print("坐标格式错误，请使用: 纬度,经度")
                        continue
                else:
                    # It's an address
                    coords = await tester.geocode_address(user_input)
                    if coords:
                        order = len(destinations) + 1
                        destinations.append((coords[0], coords[1], user_input, order))
                        print(f"已添加目的地 #{order}")

                # Ask if user wants to add more waypoints
                if destinations:
                    more = input("添加更多途经点? (y/n): ").strip().lower()
                    if more != "y":
                        break

        # 5. Send navigation commands
        if not destinations:
            print("\n错误: 未指定任何目的地")
            return

        print("\n" + "=" * 60)
        print(f"发送 {len(destinations)} 个导航点到车机")
        print("=" * 60)

        for lat, lng, desc, order in destinations:
            success = await tester.send_navigation(lat, lng, order, desc)
            if not success:
                print(f"\n警告: 导航点 #{order} 发送失败")

        print("\n" + "=" * 60)
        print("导航测试完成!")
        print("=" * 60)


def get_token_from_env() -> str:
    """Get Tesla access token from environment."""
    token = os.getenv("TESLA_ACCESS_TOKEN", "")
    if not token:
        print("错误: .env 文件中未找到 TESLA_ACCESS_TOKEN")
        print("\n请先完成 OAuth 授权并将 token 添加到 .env 文件:")
        print("  1. 启动后端服务: uvicorn app.main:app --reload")
        print("  2. 访问: http://localhost:8000/api/v1/auth/tesla/authorize")
        print("  3. 完成 Tesla 登录并复制 access_token")
        print("  4. 在 .env 文件中添加: TESLA_ACCESS_TOKEN=your_token_here")
        sys.exit(1)
    return token


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Tesla 导航测试脚本",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )

    parser.add_argument(
        "--token",
        help="Tesla OAuth access token (默认从 .env 读取)",
    )
    parser.add_argument(
        "--vehicle",
        help="指定车辆 ID",
    )
    parser.add_argument(
        "--destination", "-d",
        help="目的地地址",
    )
    parser.add_argument(
        "--waypoint", "-w",
        help="途经点地址 (中途停靠点)",
    )
    parser.add_argument(
        "--lat",
        type=float,
        help="目的地纬度",
    )
    parser.add_argument(
        "--lng",
        type=float,
        help="目的地经度",
    )
    parser.add_argument(
        "--no-interactive",
        action="store_true",
        help="禁用交互模式",
    )
    parser.add_argument(
        "--direct",
        action="store_true",
        help="直接发送地址到车机（不使用腾讯地图解析）",
    )

    args = parser.parse_args()

    # Get token
    token = args.token or get_token_from_env()

    # Validate coordinate args
    if (args.lat is not None) != (args.lng is not None):
        print("错误: --lat 和 --lng 必须同时指定")
        sys.exit(1)

    # Run test
    asyncio.run(
        run_navigation_test(
            token=token,
            vehicle_id=args.vehicle,
            destination=args.destination,
            waypoint=args.waypoint,
            dest_lat=args.lat,
            dest_lng=args.lng,
            interactive=not args.no_interactive,
            direct_mode=args.direct,
        )
    )


if __name__ == "__main__":
    main()
