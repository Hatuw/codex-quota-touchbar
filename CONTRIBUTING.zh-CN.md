# 贡献指南

[English](CONTRIBUTING.md) | [中文](CONTRIBUTING.zh-CN.md)

感谢你愿意改进 Codex Quota TouchBar。

## 本地设置

```bash
git clone https://github.com/Hatuw/codex-quota-touchbar.git
cd codex-quota-touchbar
swift test
./scripts/codex_quota_touchbar.sh --help
```

## 开发注意事项

- 保持 MTMR helper 可移植，不要提交机器相关的绝对路径。
- `mtmr/items.template.json` 应保持为模板文件，安装脚本会替换 `__CODEX_QUOTA_COMMAND__`。
- Touch Bar 组件要保持紧凑。修改后请运行：

  ```bash
  ./scripts/codex_quota_touchbar.sh compact-bar
  ```

- 提交 PR 前请运行 Swift 测试：

  ```bash
  swift test
  ```

## Pull Request 检查清单

- helper 脚本的 `compact-bar` 模式仍然可用。
- `mtmr/items.template.json` 是合法 JSON。
- 如果显示格式或安装步骤发生变化，文档已同步更新。
- 没有提交生成的 app bundle、下载文件、`.build` 或 `work/` 产物。
