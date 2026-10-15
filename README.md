# TodoFloat

一个 macOS 菜单栏待办小工具：按 **⌘ ⇧ Space** 呼出悬浮窗，在里面输入和查看待办。

## 安装

需要 macOS 13 及以上版本，以及 Swift（装好 Xcode 命令行工具即可）。

```bash
./build.sh --install
```

运行后会编译、安装到 `~/Applications/TodoFloat.app` 并启动。修改代码后重新运行这条命令即可更新。

## 使用

- **⌘ ⇧ Space**：打开或关闭悬浮窗
- 输入文字后按 **回车**：添加待办
- 点击左边的圆圈：标记完成或取消完成
- 鼠标移到某一条上，点击右边的垃圾桶，或者右键：删除
- **Esc**，或点击窗口外面：关闭悬浮窗
- 菜单栏图标：打开待办、在访达中显示数据文件、退出

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
  TodoStore.swift       待办数据和 JSON 存储
Resources/Info.plist    应用信息（LSUIElement：不在 Dock 显示）
build.sh                打包和安装脚本
```
