# Tesla Fleet API 接口参考文档

## 概述

本文档基于 Tesla 官方 Fleet API 文档整理，涵盖车辆数据获取、车辆控制命令、充电管理等接口。

**API 基础 URL**: `https://fleet-api.prd.na.vn.cloud.tesla.com`（北美）

**中国区 URL**: `https://fleet-api.prd.cn.vn.cloud.tesla.cn`

---

## 一、车辆信息接口 (Vehicle Endpoints)

共 29 个接口，用于获取车辆信息、状态和配置。

### 1.1 车辆列表与基本信息

| 接口名称 | 方法 | 路径 | 说明 |
|---------|------|------|------|
| list | GET | `/api/1/vehicles` | 返回账户下所有车辆列表，默认分页大小100 |
| vehicle | GET | `/api/1/vehicles/{vehicle_tag}` | 返回指定车辆的基本信息 |
| vehicle_data | GET | `/api/1/vehicles/{vehicle_tag}/vehicle_data` | 实时获取车辆完整数据（电量、位置等） |
| specs | GET | `/api/1/vehicles/{vin}/specs` | 返回车辆销售时的规格信息 |
| options | GET | `/api/1/dx/vehicles/options?vin={vin}` | 返回车辆选装配置（即将推出） |

### 1.2 车辆状态与控制

| 接口名称 | 方法 | 路径 | 说明 |
|---------|------|------|------|
| wake_up | POST | `/api/1/vehicles/{vehicle_tag}/wake_up` | 唤醒休眠中的车辆 |
| mobile_enabled | GET | `/api/1/vehicles/{vehicle_tag}/mobile_enabled` | 检查车辆是否启用移动设备访问 |
| fleet_status | POST | `/api/1/vehicles/fleet_status` | 获取车辆状态与应用相关信息 |

**fleet_status 响应字段**:
- `vehicle_command_protocol_required`: 是否需要车辆命令协议
- `firmware_version`: 固件版本
- `fleet_telemetry_version`: 车队遥测版本
- `total_number_of_keys`: 车辆钥匙数量（最多20把）

### 1.3 充电站与导航

| 接口名称 | 方法 | 路径 | 说明 |
|---------|------|------|------|
| nearby_charging_sites | GET | `/api/1/vehicles/{vehicle_tag}/nearby_charging_sites` | 获取车辆当前位置附近的充电站 |

### 1.4 驾驶员管理

| 接口名称 | 方法 | 路径 | 说明 |
|---------|------|------|------|
| drivers | GET | `/api/1/vehicles/{vehicle_tag}/drivers` | 获取车辆所有授权驾驶员（仅车主） |
| drivers_remove | DELETE | `/api/1/vehicles/{vehicle_tag}/drivers` | 撤销驾驶员访问权限 |

### 1.5 车辆共享

| 接口名称 | 方法 | 路径 | 说明 |
|---------|------|------|------|
| share_invites | GET | `/api/1/vehicles/{vehicle_tag}/invitations` | 获取有效的共享邀请 |
| share_invites create | POST | `/api/1/vehicles/{vehicle_tag}/invitations` | 创建共享邀请（24小时有效，一次性使用） |
| share_invites redeem | POST | `/api/1/invitations/redeem` | 兑换共享邀请 |
| share_invites revoke | POST | `/api/1/vehicles/{vehicle_tag}/invitations/{id}/revoke` | 撤销共享邀请 |

**共享邀请说明**:
- 每辆车最多5个驾驶员
- 被邀请者获得：实时位置查看、远程命令发送、个人资料下载权限
- 不需要车辆在线即可创建邀请

### 1.6 车队遥测配置

| 接口名称 | 方法 | 路径 | 说明 |
|---------|------|------|------|
| fleet_telemetry_config create | POST | `/api/1/vehicles/fleet_telemetry_config` | 配置车辆连接自托管遥测服务器 |
| fleet_telemetry_config get | GET | `/api/1/vehicles/{vehicle_tag}/fleet_telemetry_config` | 获取遥测配置 |
| fleet_telemetry_config delete | DELETE | `/api/1/vehicles/{vehicle_tag}/fleet_telemetry_config` | 删除遥测配置 |
| fleet_telemetry_errors | GET | `/api/1/vehicles/{vehicle_tag}/fleet_telemetry_errors` | 获取最近的遥测错误 |

**遥测配置限制**:
- 最多3个第三方应用可同时流传数据
- 每辆车最多5个配置
- 不支持2021年前的 Model S/X
- 需要固件版本 2023.20 或更高

### 1.7 其他信息

| 接口名称 | 方法 | 路径 | 说明 |
|---------|------|------|------|
| recent_alerts | GET | `/api/1/vehicles/{vehicle_tag}/recent_alerts` | 获取最近警报列表 |
| release_notes | GET | `/api/1/vehicles/{vehicle_tag}/release_notes` | 获取固件版本信息 |
| service_data | GET | `/api/1/vehicles/{vehicle_tag}/service_data` | 获取车辆维护状态 |
| warranty_details | GET | `/api/1/dx/warranty/details` | 获取保修信息 |
| eligible_subscriptions | GET | `/api/1/dx/vehicles/subscriptions/eligibility?vin={vin}` | 获取可用订阅 |
| eligible_upgrades | GET | `/api/1/dx/vehicles/upgrades/eligibility?vin={vin}` | 获取可用升级 |

---

## 二、车辆命令接口 (Vehicle Commands)

共 66 个命令接口，用于远程控制车辆。所有命令使用 **POST** 方法。

**基础路径**: `/api/1/vehicles/{vehicle_tag}/command/`

**重要说明**:
- 需要车队钥匙与车辆配对
- 大多数命令需要通过车辆命令代理签署请求
- 未签署的命令将被车辆拒绝

### 2.1 车门与车窗控制

| 命令 | 路径后缀 | 说明 |
|------|---------|------|
| door_lock | `door_lock` | 锁车门 |
| door_unlock | `door_unlock` | 解锁车门 |
| actuate_trunk | `actuate_trunk` | 控制前/后备箱 |
| window_control | `window_control` | 控制车窗（vent/close），需停放 |
| sun_roof_control | `sun_roof_control` | 控制天窗（stop/close/vent） |
| charge_port_door_open | `charge_port_door_open` | 打开充电口盖 |
| charge_port_door_close | `charge_port_door_close` | 关闭充电口盖 |

### 2.2 充电控制

| 命令 | 路径后缀 | 说明 |
|------|---------|------|
| charge_start | `charge_start` | 开始充电 |
| charge_stop | `charge_stop` | 停止充电 |
| charge_standard | `charge_standard` | 标准充电模式 |
| charge_max_range | `charge_max_range` | 最大续航充电模式 |
| set_charge_limit | `set_charge_limit` | 设置充电限额百分比 |
| set_charging_amps | `set_charging_amps` | 设置充电电流 |
| add_charge_schedule | `add_charge_schedule` | 添加充电计划 |
| remove_charge_schedule | `remove_charge_schedule` | 删除充电计划 |

**已弃用命令**（固件 2024.26+）:
- `set_scheduled_charging` - 使用 `add_charge_schedule` 替代
- `set_scheduled_departure` - 使用 `add_precondition_schedule` 替代

### 2.3 空调与温度控制

| 命令 | 路径后缀 | 说明 |
|------|---------|------|
| auto_conditioning_start | `auto_conditioning_start` | 开启空调 |
| auto_conditioning_stop | `auto_conditioning_stop` | 关闭空调 |
| set_temps | `set_temps` | 设置驾驶员/乘客温度 |
| set_preconditioning_max | `set_preconditioning_max` | 设置空调预处理 |
| add_precondition_schedule | `add_precondition_schedule` | 添加预处理计划 |
| remove_precondition_schedule | `remove_precondition_schedule` | 删除预处理计划 |
| set_bioweapon_mode | `set_bioweapon_mode` | 生物武器防御模式开/关 |
| set_cabin_overheat_protection | `set_cabin_overheat_protection` | 设置车辆过热保护 |
| set_cop_temp | `set_cop_temp` | 过热保护温度（0低/1中/2高） |
| set_climate_keeper_mode | `set_climate_keeper_mode` | 温度保持模式（0关/1保持/2宠物/3露营） |

### 2.4 座椅与方向盘加热

| 命令 | 路径后缀 | 说明 |
|------|---------|------|
| remote_seat_heater_request | `remote_seat_heater_request` | 设置座椅加热 |
| remote_seat_cooler_request | `remote_seat_cooler_request` | 设置座椅冷却 |
| remote_auto_seat_climate_request | `remote_auto_seat_climate_request` | 自动座椅加热/冷却 |
| remote_steering_wheel_heater_request | `remote_steering_wheel_heater_request` | 方向盘加热开/关 |
| remote_steering_wheel_heat_level_request | `remote_steering_wheel_heat_level_request` | 设置方向盘温度 |
| remote_auto_steering_wheel_heat_climate_request | `remote_auto_steering_wheel_heat_climate_request` | 自动方向盘加热 |

**注意**: 座椅和方向盘加热命令需要先开启预处理或温度保持器

### 2.5 导航

| 命令 | 路径后缀 | 说明 |
|------|---------|------|
| navigation_request | `navigation_request` | 发送位置到车载导航 |
| navigation_gps_request | `navigation_gps_request` | 导航到指定坐标（支持多停靠点） |
| navigation_sc_request | `navigation_sc_request` | 导航到超级充电站 |
| navigation_waypoints_request | `navigation_waypoints_request` | 发送航点列表 |

### 2.6 媒体控制

| 命令 | 路径后缀 | 说明 |
|------|---------|------|
| media_toggle_playback | `media_toggle_playback` | 播放/暂停切换 |
| media_next_track | `media_next_track` | 下一曲 |
| media_prev_track | `media_prev_track` | 上一曲 |
| media_next_fav | `media_next_fav` | 下一首收藏 |
| media_prev_fav | `media_prev_fav` | 上一首收藏 |
| media_volume_down | `media_volume_down` | 音量降低一格 |
| adjust_volume | `adjust_volume` | 调节音量（需用户在场） |

### 2.7 安全与模式

| 命令 | 路径后缀 | 说明 |
|------|---------|------|
| set_sentry_mode | `set_sentry_mode` | 启用/禁用哨兵模式 |
| set_valet_mode | `set_valet_mode` | 开启代客模式（需4位密码） |
| reset_valet_pin | `reset_valet_pin` | 删除代客模式PIN |
| set_pin_to_drive | `set_pin_to_drive` | 设置4位驾驶PIN |
| clear_pin_to_drive_admin | `clear_pin_to_drive_admin` | 停用驾驶PIN（仅管理员） |
| reset_pin_to_drive_pin | `reset_pin_to_drive_pin` | 移除驾驶PIN |
| guest_mode | `guest_mode` | 限制访客驾驶员功能（需固件2024.14+） |

### 2.8 速度限制

| 命令 | 路径后缀 | 说明 |
|------|---------|------|
| speed_limit_activate | `speed_limit_activate` | 激活限速模式（需4位PIN） |
| speed_limit_deactivate | `speed_limit_deactivate` | 停用限速模式 |
| speed_limit_set_limit | `speed_limit_set_limit` | 设置最大速度（英里/小时） |
| speed_limit_clear_pin | `speed_limit_clear_pin` | 停用限速并重置PIN |
| speed_limit_clear_pin_admin | `speed_limit_clear_pin_admin` | 管理员停用限速（需固件2023.38+） |

### 2.9 其他命令

| 命令 | 路径后缀 | 说明 |
|------|---------|------|
| remote_start_drive | `remote_start_drive` | 远程启动车辆（需启用无钥匙驾驶） |
| flash_lights | `flash_lights` | 闪烁前灯（需停放） |
| honk_horn | `honk_horn` | 鸣笛（需停放） |
| trigger_homelink | `trigger_homelink` | 打开HomeLink |
| remote_boombox | `remote_boombox` | 车外扬声器播放（0随机，2000定位） |
| set_vehicle_name | `set_vehicle_name` | 更改车辆名称 |
| schedule_software_update | `schedule_software_update` | 安排软件更新 |
| cancel_software_update | `cancel_software_update` | 取消软件更新 |
| erase_user_data | `erase_user_data` | 删除用户数据（需停放） |
| upcoming_calendar_entries | `upcoming_calendar_entries` | 获取日历条目 |

---

## 三、充电管理接口 (Charging Endpoints)

| 接口名称 | 方法 | 路径 | 说明 | 状态 |
|---------|------|------|------|------|
| charging_history | GET | `/api/1/dx/charging/history` | 分页充电历史 | 即将推出 |
| charging_invoice | GET | `/api/1/dx/charging/invoice/{id}` | 充电发票详情 | 可用 |
| charging_sessions | GET | `/api/1/dx/charging/sessions` | 充电会话（含价格和能源数据） | 即将推出 |

**注意**: `charging_sessions` 仅限企业车队账户所有者访问

---

## 四、TePlanner 项目常用接口

根据项目需求，以下接口最为常用：

### 核心数据获取

```python
# 1. 获取车辆列表
GET /api/1/vehicles

# 2. 唤醒车辆
POST /api/1/vehicles/{vehicle_tag}/wake_up

# 3. 获取车辆完整数据（电量、位置等）
GET /api/1/vehicles/{vehicle_tag}/vehicle_data

# 4. 获取附近充电站
GET /api/1/vehicles/{vehicle_tag}/nearby_charging_sites
```

### 充电控制

```python
# 设置充电限额
POST /api/1/vehicles/{vehicle_tag}/command/set_charge_limit
Body: {"percent": 80}

# 开始充电
POST /api/1/vehicles/{vehicle_tag}/command/charge_start

# 停止充电
POST /api/1/vehicles/{vehicle_tag}/command/charge_stop
```

### 导航

```python
# 导航到充电站
POST /api/1/vehicles/{vehicle_tag}/command/navigation_sc_request
Body: {"id": "supercharger_id", "order": 1}

# 导航到坐标
POST /api/1/vehicles/{vehicle_tag}/command/navigation_gps_request
Body: {"lat": 31.2304, "lon": 121.4737}
```

---

## 五、错误处理

### 常见错误码

| 错误码 | 说明 | 处理方式 |
|--------|------|----------|
| 401 | 未授权 | 刷新 Token |
| 403 | 权限不足 | 检查 Scope |
| 404 | 资源不存在 | 检查 vehicle_tag |
| 408 | 车辆离线 | 先调用 wake_up |
| 429 | 请求过频 | 指数退避重试 |
| 500 | 服务器错误 | 重试 |
| 503 | 服务不可用 | 稍后重试 |

### 车辆离线处理

```python
async def ensure_vehicle_online(client, vehicle_id):
    """确保车辆在线"""
    for attempt in range(5):
        data = await client.get_vehicle_data(vehicle_id)
        if data.get("state") == "online":
            return data

        await client.wake_up(vehicle_id)
        await asyncio.sleep(2 ** attempt)

    raise Exception("Vehicle offline")
```

---

## 六、权限范围 (Scopes)

| Scope | 说明 |
|-------|------|
| `openid` | 基础认证 |
| `email` | 获取用户邮箱 |
| `offline_access` | 获取刷新令牌 |
| `vehicle_device_data` | 读取车辆数据 |
| `vehicle_location` | 读取车辆位置 |
| `vehicle_cmds` | 发送车辆命令 |
| `vehicle_charging_cmds` | 充电相关命令 |

---

## 七、参考链接

- [Tesla Fleet API 官方文档](https://developer.tesla.com/docs/fleet-api)
- [Tesla 中国开发者文档](https://developer.tesla.cn/docs/fleet-api)
- [Vehicle Command SDK](https://github.com/teslamotors/vehicle-command)
