param(
    [string]$PythonExecutable = 'python'
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$required = @(
    'SKILL.md',
    'README.md',
    'CHANGELOG.md',
    'CONTRIBUTING.md',
    'LICENSE',
    'requirements.txt',
    'agents\openai.yaml',
    'references\authoring-rules.md',
    'references\companion-skills.md',
    'references\deck-analysis-report.md',
    'references\final-audit.md',
    'references\guided-workflow.md',
    'references\humanize-protocol.md',
    'references\teacher-oral-delivery.md',
    'references\quality-benchmarks.md',
    'templates\notes-template.md',
    'templates\deck-analysis-template.md',
    'templates\fact-card-template.md',
    'templates\state-template.json',
    'examples\page-type-examples.md',
    'tests\fixtures\export-sample.md',
    'scripts\audit_notes.ps1',
    'scripts\build_notes_json.py',
    'scripts\inject_notes.py',
    'scripts\export_docx.py',
    'scripts\workflow_state.py',
    'tests\smoke_test.py',
    '.github\workflows\validate.yml'
)

foreach ($relative in $required) {
    $path = Join-Path $root $relative
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing required file: $relative"
    }
}

$skill = Get-Content -Raw -LiteralPath (Join-Path $root 'SKILL.md')
if ($skill -notmatch '(?s)^---\s*\r?\nname:\s*university-ppt-notes\s*\r?\ndescription:.+?\r?\n---') {
    throw 'SKILL.md frontmatter is invalid.'
}
foreach ($companion in @('ppt-speech-writer', 'humanize')) {
    if ($skill -notmatch [regex]::Escape($companion)) {
        throw "SKILL.md does not describe companion skill: $companion"
    }
}
foreach ($dependencyReminder in @('伙伴Skill检查卡', '两个伙伴Skill都需要另行安装', '教师口述协议属于本Skill内部流程', '不能悄悄降级')) {
    if ($skill -notmatch [regex]::Escape($dependencyReminder)) {
        throw "SKILL.md is missing dependency reminder: $dependencyReminder"
    }
}

$oralProtocol = Get-Content -Raw -LiteralPath (Join-Path $root 'references\teacher-oral-delivery.md')
foreach ($requiredRule in @('讲得准确', '讲得顺畅', '听得明白', '不预先分档', '只听一遍', '正常大学课堂语速连续试讲', '不能只替换近义词或补一个连接词')) {
    if ($oralProtocol -notmatch [regex]::Escape($requiredRule)) {
        throw "Teacher oral-delivery protocol is missing required rule: $requiredRule"
    }
}


$humanizeProtocol = Get-Content -Raw -LiteralPath (Join-Path $root 'references\humanize-protocol.md')
foreach ($requiredRule in @('非文章式事实卡', '直接成文', '检测模式', '用户确认稿：最小必要修改', '回到事实卡重新生成整页')) {
    if ($humanizeProtocol -notmatch [regex]::Escape($requiredRule)) {
        throw "Humanize protocol is missing required rule: $requiredRule"
    }
}

$deckReport = Get-Content -Raw -LiteralPath (Join-Path $root 'references\deck-analysis-report.md')
foreach ($requiredRule in @('取证覆盖', '章节与页面组结构', '全讲逻辑关系', '视觉内容清单', '详略规划', '用户确认前不得生成P01—P05')) {
    if ($deckReport -notmatch [regex]::Escape($requiredRule)) {
        throw "Deck analysis report is missing required rule: $requiredRule"
    }
}

$guided = Get-Content -Raw -LiteralPath (Join-Path $root 'references\guided-workflow.md')
foreach ($scope in @('单页要求', '当前批次要求', '本课程后续规则', 'Skill通用规则')) {
    if ($guided -notmatch [regex]::Escape($scope)) {
        throw "Guided workflow is missing feedback scope: $scope"
    }
}
if ($guided -notmatch '状态文件仍不保存这些要求' -or $guided -notmatch '用户另开新任务后，不继承') {
    throw 'Guided workflow does not protect course-specific feedback from state or cross-task leakage.'
}
foreach ($intakeRule in @('确认卡', '按各模块分别计算', '简讲100—110字', '知识新颖度', '重复扣分', '初始档位', '教学功能', '背景页', '小结页', '详略分配', '课堂思考页和视频页', '硬限制', '最多出现一次')) {
    if ($guided -notmatch [regex]::Escape($intakeRule)) {
        throw "Guided workflow is missing startup confirmation rule: $intakeRule"
    }
}
if ($guided -notmatch '全讲分析报告确认' -or $guided -notmatch '用户确认报告后') {
    throw 'Guided workflow does not enforce deck-analysis approval before first-batch drafting.'
}

$license = Get-Content -Raw -LiteralPath (Join-Path $root 'LICENSE')
if ($license -notmatch '^MIT License' -or $license -notmatch 'Copyright \(c\) 2026 余京泽') {
    throw 'LICENSE is missing the expected MIT copyright notice.'
}

$auditJson = & (Join-Path $root 'scripts\audit_notes.ps1') `
    -NotesPath (Join-Path $root 'tests\fixtures\export-sample.md') `
    -ExpectedSlideCount 5
$audit = $auditJson | ConvertFrom-Json
if ($audit.issue_count -ne 0) {
    $audit.issues | ConvertTo-Json -Depth 5 | Write-Output
    throw 'Export fixture failed audit.'
}

$example = Get-Content -Raw -LiteralPath (Join-Path $root 'examples\page-type-examples.md')
$typeMatches = [regex]::Matches($example, '(?m)^## 类型[^：\r\n]*：')
$sourcePageMatches = [regex]::Matches($example, '(?m)^### P\d+\s+')
if ($typeMatches.Count -ne 12 -or $sourcePageMatches.Count -ne 12) {
    throw 'Page-type example must contain exactly twelve labeled page types and twelve source pages.'
}

$pythonScripts = @(
    (Join-Path $root 'scripts\build_notes_json.py'),
    (Join-Path $root 'scripts\inject_notes.py'),
    (Join-Path $root 'scripts\export_docx.py'),
    (Join-Path $root 'scripts\workflow_state.py')
)
foreach ($script in $pythonScripts) {
    & $PythonExecutable -m py_compile $script
    if ($LASTEXITCODE -ne 0) { throw "Python compile failed: $script" }
}

& $PythonExecutable (Join-Path $root 'tests\smoke_test.py') | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'End-to-end smoke test failed.' }

$tempJson = Join-Path ([IO.Path]::GetTempPath()) ("university-ppt-notes-" + [guid]::NewGuid().ToString('N') + '.json')
try {
    & $PythonExecutable (Join-Path $root 'scripts\build_notes_json.py') `
        --input (Join-Path $root 'tests\fixtures\export-sample.md') `
        --output $tempJson | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Notes JSON generation failed.' }
    $notes = Get-Content -Raw -LiteralPath $tempJson | ConvertFrom-Json
    if (@($notes).Count -ne 5) { throw 'Notes JSON does not contain five slides.' }
    if ($notes[0].notes -match '^P0*1\b' -or $notes[0].notes -match '封面') {
        throw 'Notes JSON contains a page number or slide title.'
    }
} finally {
    if (Test-Path -LiteralPath $tempJson) { Remove-Item -LiteralPath $tempJson -Force }
}

[pscustomobject]@{
    package = 'university-ppt-notes'
    required_files = $required.Count
    example_types = 12
    fixture_pages = 5
    audit_issues = 0
    smoke_test = 'passed'
    status = 'passed'
} | ConvertTo-Json -Compress
