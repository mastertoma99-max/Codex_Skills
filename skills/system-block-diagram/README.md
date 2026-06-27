# System Block Diagram Skill

位置：`/home/toma/.codex/skills/system-block-diagram`

这个 skill 用于根据项目设计资料绘制或修改原理图风格的系统框图。可参考的资料包括原理图、DSN/BRD 路径说明、IO 分配表、BOM、器件规格书、已有框图截图和历史版本图纸。

## 使用方法

在请求中直接提到这个 skill：

```text
Use $system-block-diagram to draw a system block diagram from the current design files.
```

如果是修改已有框图，直接说明要改的位置或规则。该 skill 默认会生成下一个版本号的 SVG/PNG，不覆盖旧版本。

## 手动设计规则

可手动维护的设计偏好文件：

```text
/home/toma/.codex/skills/system-block-diagram/references/design-rules.md
```

后续新增绘图规则时，建议写到 `Manual Additions` 下面，每条规则用简短 bullet 表示。例如：

```markdown
- 摄像头相关模块固定放在左侧。
- 只有高速总线交叉时才使用较大的跨线弧。
- 对外发布版本不显示 source note。
```

绘图前，skill 会读取这些规则，并把它们作为用户偏好处理；如果当前请求有新的明确要求，则以当前请求为准。

## 主要文件

- `SKILL.md`：给 Codex 使用的工作流程和核心规则。
- `references/design-rules.md`：用户可手动追加和维护的设计规则。
- `agents/openai.yaml`：skill 显示名、简短描述和默认提示词配置。
