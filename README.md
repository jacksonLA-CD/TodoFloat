# TodoFloat

一个 macOS 菜单栏待办小工具：按 **⌘ ⇧ Space** 呼出悬浮窗，在里面输入和查看待办。

## 安装

需要 macOS 13 及以上版本，以及 Swift（装好 Xcode 命令行工具即可）。

```bash
./build.sh --install
```

运行后会编译、安装到 `~/Applications/TodoFloat.app` 并启动。修改代码后重新运行这条命令即可更新。

## 使用

**基本操作**

- **⌘ ⇧ Space**：打开或关闭悬浮窗
- 输入文字后按 **回车**：添加待办
- 点击左边的圆圈：标记完成或取消完成
- 双击某一条的文字：编辑
- 鼠标移到某一条上，点击右边的垃圾桶，或者右键：删除
- 底部的 **清除已完成**：点一次会变成“确认”，3 秒内再点一次才会清除
- **Esc**，或点击窗口外面：关闭悬浮窗

**键盘操作**

| 按键 | 作用 |
|---|---|
| ↓ / ↑ | 在列表里上下选择；从第一条再按 ↑ 回到输入框 |
| 空格 | 标记选中的一条为完成或未完成 |
| 回车 | 编辑选中的一条（编辑时回车保存，Esc 取消） |
| ⌘ ⌫ | 删除选中的一条 |
| Esc | 关闭悬浮窗 |

使用中文输入法打字时，方向键、回车、Esc 会先交给输入法处理，不会误触这些操作。

**菜单栏图标**

- 打开待办
- 在访达中显示数据文件
- 开机自动启动：勾选后登录时自动运行。第一次开启时，如果系统要求确认，会自动打开“系统设置 > 通用 > 登录项”。
- 退出

## 数据

待办保存在 `~/Library/Application Support/TodoFloat/todos.json`。如果文件损坏、无法读取，会先把它备份成 `todos.corrupt-<时间戳>.json`，不会覆盖原文件。

## 项目结构

```
Sources/TodoFloat/
  main.swift            应用入口
  AppDelegate.swift     菜单栏图标、注册快捷键
  HotKey.swift          全局快捷键（Carbon，不需要辅助功能权限）
  FloatingPanel.swift   悬浮窗
  TodoView.swift        悬浮窗界面（SwiftUI）
  TodoListModel.swift   列表选中、编辑状态和键盘操作
  TodoStore.swift       待办数据和 JSON 存储
Resources/Info.plist    应用信息（LSUIElement：不在 Dock 显示）
build.sh                打包和安装脚本
```
