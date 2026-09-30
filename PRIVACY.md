# Shelfie Privacy Policy / 隐私政策

Effective date: September 30, 2026

Shelfie (Food Shelfie) is a personal kitchen inventory and expiry reminder app by Xiaotong Wu. No Shelfie account is required. There are no advertising, analytics, or tracking SDKs.

## Inventory and photos

Food names, quantities and units, purchase, expiry and opening dates, shelf-life estimates and low-stock thresholds, notes, owners, categories, locations, photos, shopping list entries and their completion status, settings, and local search history are stored on your device by default. The app and its widgets share a private App Group container. We do not operate a server that receives your inventory.

If you enable iCloud sync, inventory records (including quantities and opening information), shopping list entries, photos, categories, locations, and search history are synchronized through Apple's CloudKit service using your Apple account. Apple processes this information under its privacy policy: https://www.apple.com/legal/privacy/. Disabling sync stops Shelfie's use of CloudKit; it does not promise removal of previously synchronized records from iCloud.

## Barcode lookup

Scanning a barcode sends the barcode to Open Food Facts to obtain product information. The service receives normal network request information, including your IP address and the app's User-Agent. Starting with version 1.2, barcode lookup retrieves text information only and does not download or attach product images; food photos are selected by the user in the entry form. Earlier versions may download product images from Open Food Facts' image servers. We do not send your inventory, notes, owners, personal photos, or search history to Open Food Facts. Its privacy policy applies to these requests: https://world.openfoodfacts.org/privacy.

Product information is provided by Open Food Facts contributors under ODbL, database contents under the Database Contents License, and product images under CC BY-SA. See https://world.openfoodfacts.org/terms-of-use.

## Optional device permissions

- Camera: scan product barcodes and read packaging dates.
- Photos: attach an image or read dates from a selected picture. Text recognition runs on your device using Apple Vision. Starting with version 1.2, a photo used for date recognition is not automatically attached as a food photo.
- Notifications: deliver local expiry reminders and weekly summaries.
- Face ID / device authentication: unlock the app using Apple's system authentication. Shelfie does not access biometric templates.

You can manage permissions in iOS Settings. Manual inventory entry remains available without camera or photo permission.

## Backup and deletion

JSON backups may contain inventory (including quantities and opening information), shopping list entries, photos, categories, locations, and search history. Export shares this file only to the location or recipient you choose. Keep backups private. Restoring a backup replaces the current inventory after confirmation. Settings → Data → Delete All deletes the app's current inventory, shopping list entries, photos, categories, locations, and search history; if sync is enabled, record deletions may also synchronize to your other devices. Separately exported backups are not deleted by the app.

## Contact

For privacy questions or support: https://github.com/xiaotwu/food-shelfie/issues. Please do not include personal inventory or private backups in public issues.

---

## 中文说明

Shelfie（Food Shelfie）由 Xiaotong Wu 开发，用于个人厨房食品管理与到期提醒。无需注册 Shelfie 账户，无广告、分析 SDK 或追踪。

食品名称、数量与单位、购买、到期和开封日期、保质期估计与低库存阈值、备注、所有者、分类、存放位置、照片、购物清单及完成状态、设置和搜索历史默认保存在设备上，应用与小组件通过私有 App Group 共享数据。开发者不运营接收库存的服务器。

启用 iCloud 同步后，库存记录（含数量与开封信息）、购物清单、照片、分类、位置和搜索历史通过 Apple CloudKit 和你的 Apple 账户同步，适用 Apple 隐私政策。关闭同步不等于删除已同步的 iCloud 记录。

扫码查询会向 Open Food Facts 发送条码，该服务可能收到 IP 地址和应用 User-Agent 等常规网络请求信息。1.2 起扫码仅获取文字资料，不下载或自动添加商品图片；食品照片由用户在表单中自行选择。旧版本可能下载商品图片，其图片服务器可能收到上述常规请求信息。不会上传个人库存、备注、所有者、个人照片或搜索历史。商品资料及图片的许可见上述 Open Food Facts 链接。

相机用于扫码和包装日期识别；照片用于添加图片或识别日期；文字识别在设备上完成；1.2 起识别日期所用图片不会自动附加为食品照片。通知为本地提醒。Face ID／设备认证由 Apple 系统处理，Shelfie 不读取生物识别模板。可在 iOS 设置中管理权限，不授权相机仍可手动录入。

JSON 备份可含库存（含数量与开封信息）、购物清单、照片、分类、位置和搜索历史，仅导出至你选择的位置或接收方。导入备份会在确认后替换当前库存。设置中的删除全部会删除当前库存、购物清单及相关数据；启用同步时，记录删除可能同步至其他设备。已导出的备份需自行删除。

隐私与支持问题请通过上述 GitHub Issues 链接联系，勿在公开问题中提供私人库存或备份。
