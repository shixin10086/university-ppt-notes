# Contributing

欢迎提交规则改进、示例、错误修复和导出脚本增强。

## 提交原则

- 不把具体课程名称、页码、案例或用户专属要求写入核心规则；Skill的内容来源只使用PPT。
- 新规则应说明如何判断同类问题，不能只记录某一句话的修改结果。
- 不提交版权不明确的PPT、课程文档、图片、视频或真实用户讲稿。
- 改动导出脚本时，要保证PPT备注不包含页码和幻灯片标题。
- 修改固定格式或字数规则时，同步更新模板、示例和审计脚本。
- 修改引导阶段或状态字段时，同步更新 `references/guided-workflow.md`、状态模板和状态脚本测试。
- 状态文件只能保存进度元数据，不能保存PPT内容、用户要求或讲稿正文。

## 本地检查

安装依赖后运行：

```powershell
python -m pip install -r requirements.txt
./scripts/check_package.ps1 -PythonExecutable python
```

提交前还应使用 Codex 的 Skill 校验工具检查 `SKILL.md`。
