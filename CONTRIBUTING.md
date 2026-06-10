# Contributing

[English](CONTRIBUTING.md) | [中文](CONTRIBUTING.zh-CN.md)

Thanks for improving Codex Quota TouchBar.

## Local Setup

```bash
git clone https://github.com/Hatuw/codex-quota-touchbar.git
cd codex-quota-touchbar
swift test
./scripts/codex_quota_touchbar.sh --help
```

## Development Notes

- Keep the MTMR helper portable. Do not commit machine-specific absolute paths.
- Keep `mtmr/items.template.json` as a template. The installer replaces `__CODEX_QUOTA_COMMAND__`.
- Keep the widget compact enough for the Touch Bar. Test changes with:

  ```bash
  ./scripts/codex_quota_touchbar.sh compact-bar
  ```

- Run Swift tests before opening a pull request:

  ```bash
  swift test
  ```

## Pull Request Checklist

- The helper script still works in `compact-bar` mode.
- `mtmr/items.template.json` is valid JSON.
- Documentation reflects any changed display format or install step.
- No generated app bundle, download, `.build`, or `work/` artifact is included.
