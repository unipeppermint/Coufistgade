# 成就系统 — 交接说明

**状态：已编译、428 个测试全通过、英文已在模拟器确认。**

> 语言：简体中文已于提审前移除，app 只发英文。下面凡是提到中文或双语的地方
> 都指当时的状态，现状见 `docs/ROADMAP.md` Phase 18。

初版是在工具失效期间盲写的，你报了「显示不全」。已定位并修复两处布局错误，详见
下面「已修复」一节。

## 新增文件

| 文件 | 作用 |
|---|---|
| `Models/Achievement.swift` | 成就定义 + 10 条目录表 + `RoundSummary` |
| `Services/AchievementTracker.swift` | 判定与查询，纯逻辑 |
| `Core/AchievementStrings.swift` | 文案访问器（独立表） |
| `Achievements.xcstrings` | 英文文案，26 条 |
| `Components/AchievementRowView.swift` | 列表行 |
| `Views/AchievementsViewController.swift` | 成就页 |
| `coufistgadeTests/AchievementTrackerTests.swift` | 21 个测试 |

## 改动的既有文件

- `Models/RoundResult.swift` — 加 `unlockedAchievements`，**带默认值**，所以既有
  调用点不该报错。若报错，说明有调用点用了位置参数。
- `Services/PersistenceManager.swift` — 加 `unlockedAchievementIDs` 与
  `unlockAchievements(_:)`
- `Game/GameScene.swift` — 加 `roundHits`
- `Views/GameViewController.swift` — 加 tracker，round 结束时判定
- `Views/HomeViewController.swift` — 最高分区块变成成就页入口
- `Views/ResultViewController.swift` — 结算页展示新解锁

## 已修复：「显示不全」

两处布局错误，都在滚动视图上，互相独立。

### 1. 底部约束方向错了（这是内容被裁的直接原因）

```swift
// 错
rowStack.bottomAnchor.constraint(
    equalTo: scrollView.bottomAnchor,
    constant: -Theme.Spacing.l    // 负值
)
```

滚动视图的裸 `bottomAnchor` 指向 **contentLayoutGuide**，不是可视区。负常量把
内容底部拉到 content guide 上方 32pt，等于声明「内容比实际行高总和还矮 32pt」——
最后一行被裁掉。

滚动视图里的底部留白必须写成正值，且方向反过来：

```swift
// 对
scrollView.contentLayoutGuide.bottomAnchor.constraint(
    equalTo: rowStack.bottomAnchor,
    constant: Theme.Spacing.l
)
```

### 2. 横向尺寸绑到了 contentLayoutGuide（循环约束）

原先五条约束全指向裸 anchor，即全部落在 content guide 上。于是内容宽度由内容自身
决定，而标签换行又依赖宽度——循环。Auto Layout 会解出某个宽度，但不保证等于屏幕宽。

正确拆法是按方向分开：

- **滚动方向（纵向）** → `contentLayoutGuide`，决定内容有多高
- **交叉方向（横向）** → `frameLayoutGuide`，宽度必须来自屏幕

### 3. 顺带修的：`AchievementRowView` 的进度条

`textStack.alignment` 原本是 `.leading`，进度条会缩到自身固有宽度（很窄）。当初为了
补救，加了 `progressBar.widthAnchor == textStack.widthAnchor` —— 把子视图宽度反绑到
父 stack，又是一处循环。

正解是改 alignment 为 `.fill`，然后删掉那条约束。标签本身有 `numberOfLines = 0`，
`.fill` 下照样换行。

### 教训

这三处是同一个错误的三个面：**用约束去反推尺寸，而尺寸本该由外部给定**。滚动视图
两条 layout guide 的分工不是可选风格，是唯一正确写法。

## 设计取舍

**为什么单独一张 xcstrings 表**：成就会随版本增加，一次加两条 key。让它独立，
主表那 32 条已验证的字符串就不会每次被牵动。我也读不到主表，改它风险太大。

**为什么存 id 而不是索引**：目录表将来会插入新条目，索引会整体错位，把玩家已拿到
的成就变成别的成就。id 是稳定键，**不可修改**。

**为什么单局成就没有进度条**：上一局得 300 分不代表离「单局 500 分」更近。生涯类
（累计局数、历史最高）才有真实进度。

**判定必须在 `store.record` 之后**：生涯指标要包含刚结束这一局，否则「累计 10 局」
永远差一局才解锁。这行顺序有注释标注，不要调换。

**为什么不用 UITableView**：成就固定十条，没有复用需求；而 cell 复用正是 Phase 14
咬过一次的地方（`prepareForReuse` 清掉了闭包）。

## 已知不足 —— 均已解决

这一节原来列了五条,写在工具失效期间。现在全部处理完了,留着记录当时的状态:

- ~~**首页入口不可见。**~~ 已加显式按钮:`HomeViewController.achievementsButton`,
  44pt 图标,挂在设置按钮旁边,带无障碍标签。
- ~~**`bestScore` / `bestCombo` 两个指标没有对应成就。**~~ 已从
  `AchievementMetric` 删除。没有成就用它们,留着枚举 case 读起来像漏了东西;要加
  回来就得连文案一起加,那是产品决定,不是补空缺。
- ~~**没有解锁瞬间的反馈。**~~ 已接:`AudioService.playAchievementUnlock()` 与
  `HapticService.playAchievementUnlock()`,在 `viewDidAppear` 播,一局只播一次。
- ~~**`AchievementsViewController` 没有测试。**~~ 已有
  `AchievementsViewControllerTests`。
- ~~**文档未更新。**~~ 已补:`PRD.md` §10a、`UI_DESIGN.md` §15a、`ROADMAP.md`
  Phase 20a。Achievements 已从 PRD Future Features 移出。

## 仍然开着的

- **未在真机上跑过。** 帧率与手感需要 Phase 21 的真机验证,模拟器给不出结论。

## 已验证

- 编译：Debug 通过
- 测试：428 个全通过
- 模拟器：英文确认过，10 条成就完整显示，进度条正常
- 小屏：SE 尺寸（375×667）由测试覆盖 —— 没有小屏模拟器可装，未在设备上看过

布局测试是针对这次的 bug 写的，专门验证两件事：内容高度必须覆盖所有行高总和，
以及各行宽度必须等于屏幕宽而非内容宽。这两条都会在旧代码上失败。

## 调试开关

`-startInAchievements` 直接进成就页。触摸无法在模拟器里自动化，所以脚本点不到
首页那个按钮。

## 下一步

1. 真机确认手感与英文排版（Phase 21）
