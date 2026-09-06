# University PPT Notes

[![validate](https://github.com/shixin10086/university-ppt-notes/actions/workflows/validate.yml/badge.svg)](https://github.com/shixin10086/university-ppt-notes/actions/workflows/validate.yml)

一个面向中文大学课程PPT的 Codex Skill。它先读取并渲染整套PPT，梳理教学主线和详略，再按5页一批生成可以直接讲授的逐页备稿，经用户确认后导出Word并写入PPT备注。

## 设计重点

- PPT是课程事实的唯一文件来源。
- 先提交整讲分析，用户确认后再生成前5页。
- 每批参考前5页和后5页，避免页间跳跃和案例重复。
- 专业准确、教学清楚优先，口述感来自连贯解释而非口头禅。
- Humanize只检测并最小化修改明确问题，不无条件重写整稿。
- 用户确认前不写入累计稿，页码完整性由流程和脚本检查。
- 错误示例只用于按需诊断，不作为生成前的禁用词表。

## 安装与依赖

将仓库克隆到 Codex skills 目录：

```powershell
$codexRoot = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
git clone https://github.com/shixin10086/university-ppt-notes.git (Join-Path $codexRoot 'skills\university-ppt-notes')
```

重新打开任务后使用。完整流程还需要另行安装：

- `ppt-speech-writer`：PPT提取、渲染、视觉复核和备注写入；
- `humanize`：AI式表达检测和最小修改。

教师口述检查已经包含在本Skill内，无须单独安装。导出脚本依赖可通过以下命令安装：

```powershell
python -m pip install -r requirements.txt
```

## 使用方式

可以直接说：

> 使用 university-ppt-notes，只读取目录中的PPT。先渲染整套PPT并提交教学主线、页面组逻辑、视觉重点和详略规划，确认后再每5页生成逐页备稿。

Skill开始时会一次性确认处理范围、授课对象、字数口径、重点或简讲页和交付形式。默认字数如下：

| 页面类型 | 默认范围 |
| --- | --- |
| 普通页引入 | 不超过60字 |
| 正文简讲 | 100—110字 |
| 正文常规 | 110—130字 |
| 正文重点 | 130—160字 |
| 正文核心 | 160—190字 |
| 普通页收束 | 35—45字 |
| 封面 | 150—200字 |
| 目录 | 80—120字 |
| 章节过渡 | 60—90字 |

用户可以回复“全部按默认”，也可以指定重点页、简讲页或自定义字数。

## 工作流

1. 检查PPT及两个伙伴Skill，确认本次设置。
2. 提取、渲染并视觉复核整套PPT。
3. 提交全讲分析，用户确认教学主线、详略和关键视觉。
4. 按5页生成，提交前核对页码集合。
5. Humanize与教师口述检查合并为一次最小修改复核。
6. 在聊天中展示；用户确认后才写入累计稿。
7. 完稿后进行完整性、事实、教学、详略和连续试讲检查。
8. 从同一累计稿导出Word和带备注PPT副本。

详细行为见 [SKILL.md](SKILL.md)。核心规则位于 [authoring-rules.md](references/authoring-rules.md)，问题示例位于 [quality-benchmarks.md](references/quality-benchmarks.md)，后者只按需读取。

## 累计稿格式

普通内容页使用：

```markdown
## P04 页面标题

【引入】

一句完整的引入。

【备稿】

正文。

【收束】

一句完整的当前页结论。
```

PPT备注中只写实际讲授模块，不写页码、标题、字数、档位或审核说明。

## 校验与导出

```powershell
./scripts/audit_notes.ps1 -NotesPath ./notes.md -ExpectedSlideCount 40
python ./scripts/build_notes_json.py --input ./notes.md --output ./notes.json
python ./scripts/export_docx.py --input ./notes.md --output ./course-notes.docx
python ./scripts/inject_notes.py --input ./course.pptx --output ./course-with-notes.pptx --notes ./notes.json
./scripts/check_package.ps1 -PythonExecutable python
```

质量示例见 [page-type-examples.md](examples/page-type-examples.md)。仓库不包含课程PPT、用户文档或完整课程讲稿。

## 许可证

本项目采用 [MIT License](LICENSE)，Copyright (c) 2026 余京泽。
