# 自适应顶部导航 — 1.2（23）

2026-09-30 应用户追加需求，完成这一项局部改动，原更新计划仍暂停。

- 全局页面按本页本地化标题、字号与实际页面宽度预留标题和返回空间。空间不足时，三个操作收进右侧“···”；空间恢复时重新展开。
- 切换使用 0.24 秒宽度过渡、淡入淡出和轻微缩放；系统开启“减少动态效果”时移除动画。计算独立于当前收起状态，避免宽度边界反复切换。
- 菜单保留搜索、排序/过期筛选、扫码、手动添加及最近购买；原生返回保留。

两项新增 UI 测试全部通过，零编译警告：`/tmp/shelfie-adaptive-toolbar-verified.xcresult`，见[持久摘要](qa/build23-adaptive-toolbar-ui-summary.json)。验证了窄屏 Notifications 全标题宽度、竖屏收起/横屏展开/回竖屏收起，以及搜索、排序和手动添加跳转，短标题回到三个按钮。不修改库存，未触发通知授权。

[竖屏收起截图](qa/build23-adaptive-notifications-portrait-collapsed.png) · [横屏展开截图](qa/build23-adaptive-notifications-landscape-expanded.png) · [添加表单](qa/build23-adaptive-add-from-overflow.png)

中间验证如实记录：首次使用 440 点宽的 QA 手机，标题原本已有足够空间，因此未折叠；改用专用 402 点宽模拟器验证折叠。随后修正测试对设置页返回时保留导航位置的假设，并用独立可访问标识区分“添加”子菜单与手动添加按钮。最终业务和标题断言均保留并通过。

真机正常签名构建零警告，1.2（23）已覆盖安装到此前连接的 iPhone 15 Pro，并以普通参数启动；构建（本机留存证据，未纳入公开仓库：`qa/build23-device-build.log`）、安装（本机留存证据，未纳入公开仓库：`qa/build23-device-install.log`）、启动（本机留存证据，未纳入公开仓库：`qa/build23-device-launch.log`）。未清空库存、未上传或替换 App Store 审核版本。此前待验收项目仍见[原交接记录](FINAL_HANDOFF.zh-CN.md)。此前 85 项逻辑测试及构建 22 的完整流程结果是历史证据，本次使用针对性的两项界面验证，不宣称重跑了全部测试。
