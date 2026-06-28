# Codex Skills

这个仓库用于保存可复用的 Codex skills。

## Skills

- `system-block-diagram`：原理图风格系统框图绘制与迭代修改 skill。
  - 当前版本：`v0.1.1`
  - 路径：`skills/system-block-diagram/`
- `orcad-schematic-check`：OrCAD/Capture DSN 原理图检查与安全批量维护 skill。
  - 路径：`skills/orcad-schematic-check/`

## 使用方式

将需要的 skill 目录复制或安装到本机 Codex skills 目录，例如：

```text
~/.codex/skills/system-block-diagram
```

然后在请求中使用：

```text
Use $system-block-diagram to draw an editable draw.io system block diagram from the current design files.
```

```text
Use $orcad-schematic-check to inspect and safely batch-fix an OrCAD/Capture DSN schematic.
```
