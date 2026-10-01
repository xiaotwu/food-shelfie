# 构建 24 原生商店截图

当前截图为 **1.2（24）** 的真实应用界面，使用两台新建的独立模拟器和虚构展示库存。没有用户照片、账号或真实库存，没有改应用源码或直接编辑 Shelfie 数据库。

| 设备 | 原生 PNG 尺寸 | 文件 |
| --- | --- | --- |
| iPhone 17 Pro Max / 6.9 英寸 | 1320×2868 | [Shelf](iphone-6.9/01-shelf.png)、[数量与开封](iphone-6.9/02-opening-and-quantity.png)、[Shopping](iphone-6.9/03-shopping.png)、[Insights](iphone-6.9/04-insights.png)、[Settings](iphone-6.9/05-settings.png) |
| iPad Pro 13-inch (M5) | 2064×2752 | [Shelf](ipad-13/01-shelf.png)、[食品详情](ipad-13/02-opening-and-quantity.png)、[Shopping](ipad-13/03-shopping.png)、[Insights](ipad-13/04-insights.png)、[Settings](ipad-13/05-settings.png) |

两个设备均运行 iOS 26.5，英语、常规字体与浅色主题；状态栏时间统一为 9:41。原生 PNG 没有裁剪、拉伸或重绘界面。iPad 最后一次捕获等待导航动画完成，避免过渡帧。文件尺寸、校验值和构建信息见 [manifest.json](manifest.json)。

## 演示数据与实际导入

[demo-v5.json](demo-v5.json) 是 2026-09-30 准备的虚构展示备份，包含 7 件活跃食品、6 件已处理食品和 4 条购物记录；不是历史兼容性样本，也不是用户备份。展示开封后的实际到期、数量单位、无日期库存与已记录批次统计。历史格式样本仍为 `../fixtures/backup-v1.json` 至 v4，不能将这份新演示文件当成 v5 历史样本。

由于无账户模拟器中的 Safari 默认下载位置未成功提供文件，最终仅将输入 JSON 文档复制到两台专用模拟器的 Files 本地文档目录。随后通过真实「Settings → Data → Import backup」系统选择器选中文件并明确确认导入；界面显示 **Backup restored**。两台 Shelf 均显示 **7 food batches**；Shopping 确认三条待买、一条已买，共四条。没有复制或改写 Shelfie 模型容器。

原生系统文件选择器使用临时独立 XCTest 工具点选，依据实际截图定位；应用页面使用正常按钮导航。临时工具、原始日志和系统选择器截图仅保留本机 `/tmp/shelfie-store-ui-harness/`，不纳入应用工程或公开仓库。

本文件仅记录截图准备，不表示 App Store 已接受、批准或正式上架；外部提交状态见 [发行记录](../../RELEASE_STATUS.md)。真实双设备同步、真人 VoiceOver、真机 iPad 分屏、弱网相机/OCR与系统通知投递仍按交接文档留档。
