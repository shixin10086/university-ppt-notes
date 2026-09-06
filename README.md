# University PPT Notes

[![validate](https://github.com/shixin10086/university-ppt-notes/actions/workflows/validate.yml/badge.svg)](https://github.com/shixin10086/university-ppt-notes/actions/workflows/validate.yml)

一个面向中文大学课程PPT的 Codex Skill，用于从真实幻灯片生成可直接讲授的逐页备稿，并完成分批审阅、Humanize、教师口述转换、试讲验收、Word导出和PPT备注写入。

它重点解决的不是“把PPT扩写成文字”，而是让每一页都承担明确的教学任务：引入完整、解释准确、详略合理、页间连贯，并能以规范的大学教师口吻连续讲授。

## 主要能力

- 读取PPT文字、版式、流程图、原理图和示意图
- 整套渲染后先提交全讲内容、逻辑关系、视觉重点和详略规划供用户确认
- 默认按5页生成，并结合前5页和后5页判断衔接与重复
- 按页面作用选择简讲、常规、重点或核心篇幅
- 保留专业准确性，同时消除PPT摘要和AI式模板表达
- 区分真正的图示与普通照片、装饰箭头、编号卡片
- 先让用户审阅，再写入唯一累计稿
- 主动显示当前阶段、确认进度和下一步可用指令
- 用只含进度元数据的本地状态文件支持中断续作
- 完稿后依次进行教学检查、连续试讲和Humanize终检
- 导出Word展示版，并把纯讲授内容写入PPT备注栏

## 仓库结构

```text
university-ppt-notes/
├─ SKILL.md
├─ agents/
│  └─ openai.yaml
├─ README.md
├─ CHANGELOG.md
├─ CONTRIBUTING.md
├─ LICENSE
├─ requirements.txt
├─ references/
│  ├─ authoring-rules.md
│  ├─ companion-skills.md
│  ├─ deck-analysis-report.md
│  ├─ final-audit.md
│  ├─ guided-workflow.md
│  ├─ humanize-protocol.md
│  └─ quality-benchmarks.md
├─ templates/
│  ├─ deck-analysis-template.md
│  ├─ fact-card-template.md
│  ├─ notes-template.md
│  └─ state-template.json
├─ examples/
│  └─ page-type-examples.md
├─ scripts/
│  ├─ audit_notes.ps1
│  ├─ build_notes_json.py
│  ├─ inject_notes.py
│  ├─ export_docx.py
│  ├─ workflow_state.py
│  └─ check_package.ps1
└─ tests/
   ├─ fixtures/
   │  └─ export-sample.md
   └─ smoke_test.py
```

端到端测试会临时创建一个5页PPT，验证Markdown转JSON、Word导出和PPT备注写入能否完整跑通。

## 安装

将整个仓库复制或克隆到 Codex skills 目录。下面的写法在 `CODEX_HOME` 未设置时会使用默认的 `.codex` 目录：

```powershell
$codexRoot = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
git clone https://github.com/shixin10086/university-ppt-notes.git (Join-Path $codexRoot 'skills\university-ppt-notes')
```

重新打开任务后，可以直接说：

> 使用 university-ppt-notes，只读取目录中的PPT。先渲染整套PPT并向我提交全讲内容、逻辑关系、视觉重点和详略规划，确认后再每5页生成逐页授课备稿。

首次运行时，Skill会先显示伙伴Skill检查卡。请按提示确认 `ppt-speech-writer` 与 `humanize` 已经安装；它们是外部Skill，不会随着本仓库自动安装。教师口述转换协议已经包含在总控Skill中，无须单独安装。

## 伙伴Skill

完整流程组合使用四个层次，但职责不会混在一起：

- `ppt-speech-writer`：只负责PPT提取、渲染、OCR、视觉盘点和最终备注写入
- `university-ppt-notes`：负责全讲分析报告、教学主线、五页生成、详略、格式、教师检查和用户确认
- `humanize`：负责根据非文章式事实卡直接成文、句间衔接和去AI感检测
- `university-ppt-notes` 内部教师可讲性重构协议：在Humanize之后按照“讲得准确、讲得顺畅、听得明白”三个目标完成必要重构和连续试讲

本仓库不会复制或自动安装两个外部伙伴Skill。首次使用前，请在Codex的可用Skill列表中确认 `ppt-speech-writer` 与 `humanize` 已经存在；缺少时，可以直接要求Codex安装对应Skill。教师口述协议随总控Skill提供，详细边界见 [伙伴Skill分工](references/companion-skills.md)。

新稿不会采用“先写完整书面初稿，再让Humanize润色”的方式，而是执行专门的 [大学讲稿强Humanize协议](references/humanize-protocol.md)：先建立非文章式事实卡，再直接完成第一次课堂成文并用检测模式复查；已经确认的页面仍保持最小必要修改。

## Python依赖

使用导出脚本前安装依赖：

```powershell
python -m pip install -r requirements.txt
```

`python-docx`用于Word导出，`python-pptx`用于PPT备注写入。版本范围锁定在已经通过自动测试的主版本内，避免未来不兼容更新直接破坏流程。

## 用户会怎样被引导

Skill默认采用“先检查伙伴Skill、开头一次确认、每5页一批、先审后写”。依赖检查会明确提醒两个外部Skill是否已经安装，并确认内部教师口述协议可用；检查完成后，再把会随课程变化的关键参数和默认值放进一条确认卡：处理范围、字数尺度、授课对象或专业程度、已知的重点/简讲偏好，以及交付形式。用户可以回复“按默认即可”，也可以只修改其中一项。

例如：

> 开始前会逐项列出字数计算方式、普通页引入上限、正文四档范围、收束范围、封面/目录/过渡页范围，以及思考页和视频页是否设限。你可以回复“全部按默认”，也可以只改某一项，例如“按模块计算，正文统一为100—130字，其他默认”。

参数确认后，Skill先提取并渲染整套PPT，再向用户完整提交全讲分析报告。报告覆盖取证情况、教学主线、章节与页面组关系、关键视觉页、详略规划、重复内容和首批页面位置；用户确认这份报告前，不会生成P01—P05。

全讲分析确认后，每一步都会用两三句话说明当前进度和下一步，例如：

> 进度：待审核P06—P10；已确认至P05，共91页。
>
> 你可以回复“通过/下一步”，或直接说“修改P08：……”。

在批次审核阶段，“下一步”表示接受刚刚展示的完整批次、写入累计稿并继续；如果用户提出修改，则先修改并重新展示，不会写入旧稿。全稿完成后，Skill会先列问题清单，得到许可后再集中返修。

每条修改意见都会标明作用范围，避免“只改这一页”被误用到整套课程，也避免“后续都注意”在下一批失效。例如：

> 已记录为本课程后续规则：案例重复出现同一流程时，后续只讲新增约束和案例特色；从P21起应用，并在全稿检查时回看。

作用范围分为单页、当前批次、本课程后续和Skill通用四级。只有用户明确要求写入Skill或用于以后所有课程时，才会修改Skill本身。

任务中断后，Skill通过 `.university-ppt-notes/state.json` 恢复页数、批次和审核阶段。这个文件不保存PPT正文、用户要求或讲稿内容，因此不会成为额外的内容来源。详细行为见 [分阶段引导与进度管理](references/guided-workflow.md)。

## 完整工作流

1. 确认PPT、当前有效进度和唯一累计稿，并用一条确认卡核对关键参数。
2. 提取并渲染整套幻灯片，建立覆盖每一页的页面清单。
3. 向用户呈现全讲教学主线、页面组逻辑、视觉清单、详略规划和去重策略。
4. 用户确认全讲分析后，用前5页、当前5页、后5页形成上下文窗口。
5. 为当前5页建立非文章式事实卡，并直接生成课堂讲稿。
6. 用Humanize检测事实卡序列化、模板表达、句间关系和相邻页结构重复；失败页重新生成。
7. 执行内部教师可讲性重构协议，不预设修改强度；逐页处理听觉顺序、主体动作、句间关系和跨页承接，并删除无教学功能的口头禅、设问与聊天化措辞。
8. 以大学教师身份连续试讲当前5页。
9. 在聊天中完整展示，用户确认后才写入累计稿。
10. 全部完成后依次做硬性检查、教学检查、连续试讲、Humanize终检和教师口述终检。
11. 从同一累计稿生成Word和PPT备注版。

详细规则见 [SKILL.md](SKILL.md)。

## 累计稿格式

复制 [templates/notes-template.md](templates/notes-template.md) 作为起点。普通内容页使用：

```markdown
## P04 页面标题

【引入】

一句完整的引入。

【备稿】

正文。

【收束】

一句完整的当前页结论。
```

封面、目录、章节过渡、课堂思考和视频页使用不同模块，详见写作规则。

## 质量示例

[page-type-examples.md](examples/page-type-examples.md) 从经过逐页审核的真实课程成稿中，为每种主要页面类型各选一页，并经版权人授权公开。它覆盖固定格式以及需要不同讲法的普通内容页，是质量参照，不会作为其他课程的内容来源。导出脚本使用独立的测试夹具，避免把测试目的和质量展示混在一起。

## 输入边界

Skill只读取PPT作为备稿内容来源，不主动查找或读取同目录中的Word、PDF、TXT等要求文件。用户在当前对话中直接提出的页码、详略或表达调整仍然有效，但不需要另建要求文档。

## 脚本用法

检查Markdown结构和字数：

```powershell
./scripts/audit_notes.ps1 -NotesPath ./tests/fixtures/export-sample.md -ExpectedSlideCount 5
```

用户采用自定义字数时，将相应范围传给审计脚本，例如：

```powershell
./scripts/audit_notes.ps1 -NotesPath ./notes.md -ExpectedSlideCount 40 -IntroMax 50 -BodyMin 100 -BodyMax 130 -ClosingMin 30 -ClosingMax 40
```

如果已经通过其他工具生成 `slide_extract.json`，可以同时核对PPT标题：

```powershell
./scripts/audit_notes.ps1 -NotesPath ./notes.md -SlideExtractPath ./slide_extract.json
```

提取结果的最小结构为：

```json
{"slides":[{"slide":1,"title":"封面"}]}
```

把累计稿转换为不含页码和标题的备注JSON：

```powershell
python ./scripts/build_notes_json.py --input ./notes.md --output ./notes.json
```

写入PPT副本：

```powershell
python ./scripts/inject_notes.py --input ./course.pptx --output ./course-with-notes.pptx --notes ./notes.json
```

生成Word展示版：

```powershell
python ./scripts/export_docx.py --input ./notes.md --output ./course-notes.docx
```

运行仓库自检：

```powershell
./scripts/check_package.ps1 -PythonExecutable python
```

初始化或查看本地进度状态：

```powershell
python ./scripts/workflow_state.py init --state ./.university-ppt-notes/state.json --ppt ./course.pptx --slide-count 91
python ./scripts/workflow_state.py show --state ./.university-ppt-notes/state.json
```

从中间页恢复时，可以在初始化命令中增加 `--target-start 6 --confirmed-through 5`。状态脚本只接受预定义的元数据字段，意外加入课程内容或写作要求会校验失败。

## 设计原则

- 专业准确优先于口语化
- 口语化体现在连贯解释，不体现在聊天化措辞
- 图示服务于知识，教师掌握讲述主动权
- 详略取决于知识是否新增，不取决于页面是否有流程
- 后续案例突出特色，不重复完整讲述共性流程
- Humanize按最终听感验收，不按“是否调用过”验收
- 教师口述层不预设修改强度，以讲得准确、讲得顺畅、听得明白为验收目标，口述感来自听觉顺序与句间关系，不来自口头禅
- 已确认内容最小修改，未确认新稿充分重写

## 发布前清单

- `scripts/check_package.ps1` 返回通过
- Skill校验工具返回有效
- README中的安装与示例命令可执行
- GitHub Actions中的Windows端到端测试通过
- 仓库中不包含课程PPT、用户文档、完整最终讲稿或临时渲染文件；质量示例仅使用版权人明确授权的12个单页节选
- 根目录包含有效的MIT `LICENSE`

## 许可证

本项目采用 [MIT License](LICENSE)，Copyright (c) 2026 余京泽。
