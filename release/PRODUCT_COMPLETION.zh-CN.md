# Shelfie 产品改进验收清单

当前发行候选版本：1.2（24）。构建 24 的最终验证与外部发布状态见 [发行状态](RELEASE_STATUS.md)。本文保留 2026-09-30（America/Los_Angeles）以来的验证证据。对应[原产品评估](PRODUCT_REVIEW.zh-CN.md)中的 7 项高优先级问题和 7 项新增功能建议，记录当前开发代码、测试证据及仍需真人或真实设备验证的边界。

本轮已经把“减少录入负担、可靠处理库存、按实际食品日期提醒”落到代码中。已留档的 1.2（22）基线中，85 项单元测试全部通过，零警告，结果为 `/tmp/shelfie-final22-unit-passed.xcresult`，持久摘要见 [build22-unit-summary.json](qa/build22-unit-summary.json)。测试产物可能随本机清理失效；摘要保留测试数量、平台和结果。代码与故障处理测试不能替代两台真机同步、真人 VoiceOver 或真实 iPad 分屏验收。

用户已接受仅一台设备导致的跨设备验收边界；此前暂时结束功能更新，随后明确恢复本次界面修复、项目整理及发行收尾。当前交接与边界见[最终交接记录](FINAL_HANDOFF.zh-CN.md)，不追加新的功能路线图。

1.2（24）现已上传并处理完成，两个现有 TestFlight 内部组均为 Testing，测试说明已保存；新版 App Store 提交与审核状态见[发行状态](RELEASE_STATUS.md)。1.1（20）Waiting for Review 属于历史观察，构建 22 交接时未替换它。文中“已实现”不表示 Apple 已批准或应用已公开上架。

## 原报告的 7 项高优先级问题

| 项目 | 已实现行为及代码 | 已有证据 | 当前状态与剩余验证 |
| --- | --- | --- | --- |
| 1. 保存失败反馈 | [食品表单](../Shelfie/Features/Entry/FoodEntryView.swift)成功保存后才关闭，失败保留草稿；[库存和详情](../Shelfie/Features/Inventory/InventoryView.swift)、[搜索及分类/位置管理](../Shelfie/Features/Search/SearchView.swift)明确显示错误并恢复操作前状态；[数据设置](../Shelfie/Features/Settings/SettingsViews.swift)显示导入/导出/删除错误；图片在数据库提交后清理。 | `ProductCompletionTests.testImportCommitFailurePreservesInventoryAndShopping`、`testPhotoWriteFailurePreservesInventory`；`ShoppingInventoryTests.testShoppingCommitFailurePreservesSavedInventoryAndPendingEdits`。第一阶段数量操作、撤销和再次购买已有模拟器操作截图。 | **已实现，故障注入测试通过。** 故障测试模拟保存失败和磁盘空间不足错误；没有把真实设备磁盘写满，也没有声称已逐页覆盖所有系统存储异常。 |
| 2. CloudKit 生产结构、默认记录去重 | [模型](../Shared/SwiftDataModels.swift)增加数量、开封、低库存和购物记录；[SeedData](../Shelfie/Data/SeedData.swift)采用稳定默认 ID，合并重复默认分类/位置并修复食品引用，独立事务保存；[RootView](../Shelfie/App/RootView.swift)收到远端变化后执行合并和刷新。实际容器 `iCloud.com.xiaotwu.shelfie` 已部署新增字段与 `ShoppingItemRecord` 生产结构，构建 22 又部署了购物转库存防重标记 `inventoryFoodID`。 | [生产部署截图](qa/cloudkit-phase2-production-deployed.png)、[结构变更记录](qa/cloudkit-phase2-deployment-diff.txt)、初始化日志（本机留存证据，未纳入公开仓库：`qa/cloudkit-schema-initialization-phase2.log`）、[构建 22 部署及启动记录](qa/build22-cloudkit-and-device-status.md)；`ProductCompletionTests.testDuplicateDefaultRecordsAreMergedAndReferencesRetained`。 | **生产结构已部署，去重逻辑测试通过；真实跨设备同步未验收。** 仍需同一 Apple 账户两台设备，以 TestFlight 构建验证新增、编辑、删除、照片、购物记录及重复默认数据恢复。个人账户同步不等于家庭共享。 |
| 3. 扫码恢复体验 | [ScannerView](../Shelfie/Features/Scanner/ScannerView.swift)支持失败后重试同一条码、手动输入、校验提示和相机权限拒绝后的设置入口；[OpenFoodFactsClient](../Shelfie/Data/OpenFoodFactsClient.swift)限制请求时间并支持取消，扫码仅请求文字商品资料，不下载或附加图片；日期识别图片亦不会自动作为食品照片；表单仍通过同一展示对象接收识别草稿。 | `ScannerDateTests` 覆盖条码空格/校验位、仅请求文字字段并忽略接口图片资料、开始前取消和查询中取消；原 1.1（19）的实际扫码自动填写已有[真机截图](qa/build19-barcode-prefill.png)。 | **已实现，网络边界测试通过。** 旧版真机证据不能代替新重试/手动输入/权限恢复完整真机流程。仍需检查弱网、系统相机拒绝及重新授权。 |
| 4. 日期解析与歧义确认 | [DateParser](../Shared/DateParser.swift)严格验证日历日期，保留原文、生产日期与到期候选；斜线日期存在日/月和月/日两种合法解释时交给用户选择；支持中文包装日期和英文月份；[扫码页](../Shelfie/Features/Scanner/ScannerView.swift)展示确认页。生产日期不会自动冒充到期日或购买日；购买日默认今天，可由用户修改。 | `ScannerDateTests` 验证无效日期、闰年、多个地区的斜线歧义、中文标签、生产日期独立处理和英文月份。 | **已实现，解析逻辑测试通过。** 没有自动猜测包装未写明的保质期。仍需用真实中文/英文包装、反光和模糊照片验证识别与确认体验。 |
| 5. 无障碍与适配 | [表单](../Shelfie/Features/Entry/FoodEntryView.swift)、[库存/购物/历史](../Shelfie/Features/Inventory/InventoryView.swift)在辅助字体下使用纵向或可换行布局；批量操作可进入菜单；[Motion](../Shelfie/Design/Motion.swift)、[Theme](../Shelfie/Design/Theme.swift)、[RootView](../Shelfie/App/RootView.swift)尊重减少动态效果；交互按钮补充可访问名称和状态。 | [辅助字体徽标截图](qa/build21-accessibility-badges.jpg)及此前模拟器操作检查；编译及本轮测试通过。 | **代码改进已实现，完整可用性验收仍未完成。** 最大辅助字体下 iPad 横竖屏详情、购物、历史和全局导航已通过模拟器界面验收；真实 iPad 分屏、真人 VoiceOver 以及未覆盖页面仍需验收。 |
| 6. 数据备份版本与故障处理 | [BackupService](../Shelfie/Data/BackupService.swift)导出 v5、恢复 v1–v5；替换和清空使用独立事务，成功后清理旧照片；验证版本、重复 ID、引用、数量、开封与图片；导出自校验，缺图不静默丢弃；实际 JSON 限制 100 MB，单图 10 MB、图片总量 50 MB，食品和购物记录各最多 10,000 条。错误支持中文。 | [v1–v4 JSON 样本](qa/fixtures/README.md)；`BackupFixtureTests` 验证 v1–v4 JSON 文件恢复、旧字段默认、自校验、大小和缺图，以及代码生成的 v5 防重标记往返；`ProductCompletionTests` 覆盖损坏 JSON、超大图片、缺失引用、提交和图片写入失败；`QuantityMigrationTests` 用旧模型创建磁盘库再升级。 | **已实现，兼容与故障测试通过。** JSON 样本是手工构造的历史格式代表，不是从每个旧发布二进制导出的用户文件。错误注入不等于真实设备磁盘写满实验。 |
| 7. 提醒长期边界及系统权限 | [NotificationScheduler](../Shelfie/Services/NotificationScheduler.swift)按每批食品的临期和到期日创建有限通知，不再限制未来 28 天；最多 60 条，优先最近投递日期，同一投递时刻优先更早到期食品；空库存不安排每日检查；可选周报只围绕有日期食品安排。[通知设置](../Shelfie/Features/Settings/SettingsViews.swift)展示真实系统权限、设置入口、计划数量和覆盖批次。[RootView](../Shelfie/App/RootView.swift)在前台、运行中日期/时区和远端数据变化时刷新。 | `ReminderRoutingTests` 覆盖空库存、远期到期、0 天预警、错过今日投递时间、纽约 DST 缺失/重复时间、60 条优先级和开封期限；`SettingsPreferenceTests` 验证损坏的持久偏好恢复安全值。 | **已实现，计划逻辑测试通过；系统投递仍需真机验收。** 超过容量时不能保证覆盖每批食品，设置页明确显示覆盖；应用关闭后不能保证自动补满通知或随远端修改重新排期。重新打开应用会刷新。专注模式和系统策略可能影响实际展示。 |

## 原报告的 7 项新增功能

| 建议 | 当前实现与代码 | 验证及明确边界 |
| --- | --- | --- |
| 数量、单位、部分消耗 | [FoodItemRecord](../Shared/SwiftDataModels.swift)支持个/包/瓶/克/千克/毫升/升；[详情和首页](../Shelfie/Features/Inventory/InventoryView.swift)支持使用一部分，余量归零才变为吃完；小数最多三位精度。 | `QuantityAndRepeatPurchaseTests` 验证部分使用、归零、小数残余、非法输入和备份；第一阶段模拟器实际完成 16 个鸡蛋 → 用 2 个 → 14 个 → 撤销 16 个。统计仍按批次，未把不同单位相加成浪费重量。 |
| 相同商品快速再次添加 | [FoodEntryDraft](../Shelfie/Features/Entry/FoodEntryView.swift)复用商品资料、分类和位置；详情及添加菜单可从活跃/已处理商品再次购买；新批次数量默认 1、购买日为今天；到期日不继承，必须明确选择新日期或“无到期日”，原批次不改变。 | `testRepeatPurchaseRequiresNewExpiryAndDoesNotChangeOriginal`，以及[再次购买模拟器截图](qa/build21-repeat-purchase.jpg)。不复制旧到期日，避免新增库存继承过期日期。 |
| 批次和开封日期 | 每次购买保留独立记录和到期日；可记录开封日期及 1–365 天开封期限；[effectiveExpiryDate](../Shared/SwiftDataModels.swift)取包装到期日与开封期限的较早值，库存、提醒、统计和小组件使用同一有效到期日。 | `ProductCompletionTests.testOpeningNeverExtendsPackageExpiry`、`ReminderRoutingTests.testOpenedShelfLifeUsesEarlierEffectiveExpiry`、v4 恢复测试。开封期限是用户填写的记录，不是应用推断的食品安全保证；没有新增批次合并或逐次消耗台账。 |
| 撤销与已处理历史 | [FoodActionSnapshot](../Shelfie/Features/Inventory/FoodDetailSheet.swift)保存最近一次数量/状态/处理日期，撤销前检查后续变化；[历史入口](../Shelfie/Features/Inventory/InventoryView.swift)可查看已吃完/丢弃记录、恢复库存或再次购买。数量已归零的历史食品恢复时需输入数量。 | `testUndoRestoresQuantityStatusAndResolutionDate`；[撤销可见截图](qa/build21-undo-visible.jpg)。最近操作撤销是当前会话快照，不是永久撤销日志；历史恢复不会虚构已归零食品的原数量。自动清理后被删除的历史无法从该入口恢复。 |
| 首页“先吃这些”行动区 | [InventoryView.useFirstSection](../Shelfie/Features/Inventory/InventoryView.swift)展示当前筛选下未来 0–7 天内最先到期的最多 3 批食品、余量和剩余天数，可打开详情、部分使用、吃完或丢弃；误操作可撤销。 | 已集成核心库存写入和有效期限规则。需要继续记录新行动区的模拟器/真机操作证据，以及用户是否因此更早处理食品；不能仅凭 UI 存在宣称减少了浪费。 |
| 购物清单与低库存 | [ShoppingListView / LowStockSuggestion / ShoppingListOperations](../Shelfie/Features/Inventory/InventoryView.swift)提供项目增改删、数量/单位、已买状态；可从食品加入；同名同单位的活跃批次合并计算余量，与阈值比较，未完成购物项目去重。v5 备份保留购物记录及转库存防重标记，CloudKit 生产已包含其结构。 | `ShoppingInventoryTests` 验证多批合计、防止误报、不同单位分离、小数阈值、已处理批次补货偏好、重复加入、编辑未被失败写入回滚和地区数字输入。勾选已买可选择“仅标记”或转库存；转库存必须明确确认到期日或无日期，食品和购物完成状态在同一事务内提交。重复操作不会再次生成批次；后续删除食品仍保留已转库存标记。 |
| 通知直接操作及小组件深链 | [应用通知代理](../Shelfie/App/ShelfieApp.swift)提供需要设备认证的前台吃完/丢弃操作；可靠保存后刷新并返回库存，普通通知点击打开对应活跃食品详情；[ShelfieRoute / AppNavigationState](../Shelfie/App/RootView.swift)验证 `shelfie://food/<UUID>`；[小组件](../ShelfieWidgets/ShelfieWidgets.swift)提供食品链接并按日期重新计算显示。 | `ReminderRoutingTests` 验证路由、失效食品、重复操作和保存；真实系统通知操作、设备认证及小组件点击仍需真机验收。小组件数据来自共享快照，系统控制刷新时机，不承诺实时后台更新。 |

## 构建 22 的最终六项改进与可跳过提示

| 项目 | 最终行为与证据 |
| --- | --- |
| 未知到期日不猜测 | 新增和编辑无日期食品保持未知，不再默认添加 7 天；再次购买明确选择新日期或无日期。`ProductCompletionTests.testMissingExpiryStaysMissingForNewAndEditedFood`、`testRepeatPurchaseNeedsExplicitDateOrNoDateChoice` 通过。 |
| OCR 生产日期不作购买日 | 扫码草稿中的购买日保留今天，识别到的生产日期只在日期确认中作参考，用户可修改真实购买日。`testConfirmedDateScanKeepsTodaysPurchaseAndNoPhoto` 通过。 |
| 真实设备验收边界 | [构建 22 记录](qa/build22-cloudkit-and-device-status.md)证明新增结构生产部署、单台 iPhone 15 Pro 安装和正常启动；不把安装/启动当作两设备同步、VoiceOver 或所有真机流程通过。 |
| 高级信息折叠及保存并继续 | 食品表单将更多信息收进可展开区域；手动添加支持保存并继续，只有成功提交后才重置到下一件食品，失败保留输入。构建 22 的新增流程界面验收已通过，见[交接证据](FINAL_HANDOFF.zh-CN.md)。 |
| 紧凑“先吃这些”与无图卡片 | 首页临期食品改为紧凑行，处理入口收进操作菜单；没有照片的库存卡片减少占位，保留名称、数量、日期状态及可访问操作。构建 22 的新增流程界面验收已通过，见[交接证据](FINAL_HANDOFF.zh-CN.md)。 |
| 购物已买可选转库存 | 买完可仅标记或打开库存表单，日期/无日期需显式确认。`FoodEntryShoppingConversion` 将食品保存、购物完成及 `inventoryFoodID` 标记同事务提交，失败不改变原购物项；重复来源被拒绝。`testShoppingConversionIsAtomicAndDuplicateSourceIsRejected` 和 `BackupFixtureTests.testV5RoundTripPreservesShoppingConversionAfterFoodDeletion` 通过。 |

首次使用提示是空库存中的就地小卡，提供添加首件食品和“以后再说”；不是强制引导页。跳过跨启动保留，更多设置可以重新显示。已有库存时不强制追踪教学步骤。`SettingsPreferenceTests` 覆盖跳过持久性与恢复提示不改其他偏好。

备份 v4 缺失 `inventoryFoodID` 时默认 nil；v5 保留该防重标记，即使已生成的食品后来删除也不会因恢复备份再次转库存。仓库的字面 JSON 历史样本仍只有 v1–v4，v5 通过代码生成的导出/恢复测试验证，没有声称存在 v5 历史文件样本。

## 本轮追加的首页气泡与统计改进

- 移除首页“X items on your shelf”总数行，在 All、各放置区域与底部 Shelf 导航右上角显示库存气泡；计数按活跃食品批次，零库存隐藏，超过 99 显示 99+。
- 设置 → 外观 → 库存气泡提示，可选择显示数字、仅红点或关闭。设置持久保存，关闭视觉提示仍为 VoiceOver 提供完整数量。`SettingsPreferenceTests.testInventoryBadgeDefaultAndAllStylesPersist` 通过；三种选项已实际界面切换验证。
- 辅助功能最大字体下，购物与历史入口纵向排列，整页可滚动，库存使用单列；设置中的主题选项纵向排列，装饰图标不会挤占大字体文字。
- 统计没有已处理批次时显示“暂无记录”和破折号，不再给出虚假的 100%；文案明确按已记录的食品批次计算吃完比例，不能代表实际重量或节省金额。
- [隐私政策](../PRIVACY.md)补充数量、开封信息与购物清单，并已单独提交和推送（`f93e46e`、`6f6e968`，后者说明 1.2 起仅查询文字及旧版图片流程）；没有将既有工作区代码全部打包提交。

## 统一顶部导航（2026-09-30 追加需求）

- Shelf、Insights、Settings 使用紧凑的原生同栏标题，标题与右上角按钮在同一行，减少原大标题占用的垂直空间。
- 搜索、排序/筛选、添加三个入口共享组件和导航状态；设置的五个子页面、搜索、购物清单与历史页面均保留这些入口及原生返回按钮。
- 任意页面搜索、添加或扫码会切换到 Shelf 后打开相应流程；排序与过期筛选共享库存状态，最近购买入口保留。
- 图标触控区域至少 44 点，补充可访问名称；请求使用独立标识，较旧页面的完成事件不能清掉新请求，重复点击仍可触发新操作。新增 4 项导航状态测试已全部通过；横竖屏详情、购物切换、跨页搜索与添加的 UI 操作已通过。追加严格检查确认标题同栏且不与操作或返回按钮重叠、数字在大字体统计卡片内；最终严格 UI 重跑通过（`/tmp/shelfie-global-toolbar-strict-2.xcresult`）。

扫码只自动填写文字资料；食品图片由用户在添加/编辑表单中自行上传。条码查询和包装日期识别均不自动附加图片，也不删除用户已保存的照片。

## 证据与待完成验收

已确认的证据：

- **构建 22 历史基线：** 85 项单元测试全部通过，零警告，结果 `/tmp/shelfie-final22-unit-passed.xcresult`；[持久摘要](qa/build22-unit-summary.json)显示 iOS 26.5 iPad 模拟器、85 通过、0 失败/跳过及无运行时警告。新增字符串的中英文字静态核对通过，`git diff --check` 通过。
- **构建 22 历史基线：** CloudKit `CD_inventoryFoodID` 生产部署、正常 Debug 构建、单台 iPhone 15 Pro 安装和启动已确认，见[记录](qa/build22-cloudkit-and-device-status.md)。正常启动没有使用 schema/QA 参数；尚不代表新增完整流程真机通过。
- **构建 22 的最终界面验证：** 四个流程分别通过：横竖屏与严格全局导航在 `/tmp/shelfie-final-ui-2.xcresult` 通过；修复卡片整面点击和长按手势优先级后，连续添加及购物转库存两个新增流程在 `/tmp/shelfie-final-new-ui-4.xcresult` 全通过。完整中间失败、最终通过及测试环境说明见[最终交接](FINAL_HANDOFF.zh-CN.md)，未将中间失败轮次计为整轮通过。
- **历史 21：** 78 项逻辑测试和当时 Release 模拟器构建通过且零警告；仅文字扫码的追加改动通过 9 项针对性测试（`/tmp/shelfie-text-only-scan.xcresult`），验证字段、品牌/分类、12 秒请求边界与仅一次请求。
- **历史 21：** 两项界面流程已通过：最大字体 iPad 横竖屏核心操作（`/tmp/shelfie-ipad-global-layout.xcresult`），严格标题、跨页排序/搜索/添加与统计卡片检查（`/tmp/shelfie-global-toolbar-strict-2.xcresult`）。见 [全局导航截图](qa/build21-global-insights-toolbar.png)、[设置子页返回与工具栏](qa/build21-global-appearance-back-and-toolbar.png)。
- **历史 21：** 当时 1.2（21）包含全局顶部导航、统计卡片大字修复和扫码仅文字规则，已成功安装到此前连接的 iPhone 15 Pro 并正常启动，设备构建零警告。见 [真机启动截图](qa/build21-global-device-launch.png)、安装记录（本机留存证据，未纳入公开仓库：`qa/build21-global-device-install.log`）。这证明安装与启动及顶部布局，不能替代当前版本真实扫码/通知/跨设备验收。
- 普通字体 iPhone 模拟器亦检查了窄屏标题、三个按钮、返回和气泡：见 [首页](qa/build21-global-phone-shelf.jpg)、[外观设置](qa/build21-global-phone-appearance.jpg)。
- 旧模型磁盘迁移、v1–v4 JSON 恢复、保存/图片写入故障、扫码请求取消、日期歧义、远期提醒/DST、购物合并及偏好恢复已进入测试。
- CloudKit 本轮新增结构已经真实部署到生产，截图和结构记录保存在 `release/qa/`。
- 第一阶段数量、撤销、再次购买等模拟器操作证据保留；本轮 iPad 竖屏模拟器已实际完成添加 Milk、记录开封后 3 天（包装到期为 7 天后）、首页显示较早期限、低库存建议加入购物清单和已买切换。见 [开封详情](qa/build21-ipad-opening-details.jpg)、[购物清单](qa/build21-ipad-shopping.jpg)。最大字体下已实际完成首页吃完→气泡 2 变 1→撤销恢复 2，撤销按钮保持在导航上方。最大辅助字体下的 iPad 横竖屏详情日期、购物状态切换、历史返回和跨页操作 UI 测试已通过（`/tmp/shelfie-ipad-global-layout.xcresult`）。这仍不能替代真机分屏与 VoiceOver。

留档的未完成验收（不自动启动新的更新计划）：

- [ ] 同一账户两台设备的 TestFlight 新增、编辑、删除与照片同步，购物记录同步及默认记录合并。
- [ ] 真人 VoiceOver 连续完成录入 → 处理 → 撤销 → 购物；确认朗读顺序、按钮名称和状态反馈。
- [ ] 真实 iPad 横屏与分屏，最大辅助字体下逐页完成核心操作。
- [ ] 当前构建的真实相机拒绝/重新授权、弱网扫码重试、实物日期歧义确认。
- [ ] 当前构建的真实通知投递、直接操作和小组件食品跳转，包括已处理/已删除食品。
- [ ] 5–10 位用户连续两周实际使用，记录重复录入耗时、提醒后处理行为及停止使用原因。

其中跨设备验证延期由用户明确接受，其余内容如实记录验证边界，未宣称用户逐项批准。上述边界不作为继续扩展功能或再次索要设备的理由。此前功能更新按用户要求暂时结束，本次已明确恢复发行收尾；上述硬件验收仍留档，不能因恢复发布准备就写成已通过。当前不能把“建议已写进代码”当作长期留存、无障碍可用性或跨设备可靠性的充分证明。

## 产品范围

此次未包含家庭共享：当前同步范围是个人 Apple 账户；尚未实现 CloudKit 分享权限、家庭成员协作及删除冲突策略。AI 食谱、社交、积分、订阅、逐次消耗台账和永久撤销记录不属于此次完成范围。

产品质量仍可用首次添加完成率、单次录入耗时、第二次购物后是否继续记录、提醒后实际处理率评估；本轮不建立新的自动跟进。当前效率指标来自用户记录的食品批次状态，不代表真实节省的重量、金钱或碳排。
