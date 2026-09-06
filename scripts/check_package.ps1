param(
    [string]$PythonExecutable = 'python'
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$required = @(
    'SKILL.md', 'README.md', 'CHANGELOG.md', 'CONTRIBUTING.md', 'LICENSE',
    'requirements.txt', 'agents\openai.yaml',
    'references\authoring-rules.md', 'references\companion-skills.md',
    'references\deck-analysis-report.md', 'references\final-audit.md',
    'references\guided-workflow.md', 'references\humanize-protocol.md',
    'references\teacher-oral-delivery.md', 'references\quality-benchmarks.md',
    'templates\notes-template.md', 'templates\deck-analysis-template.md',
    'templates\fact-card-template.md', 'templates\state-template.json',
    'examples\page-type-examples.md', 'tests\fixtures\export-sample.md',
    'scripts\audit_notes.ps1', 'scripts\build_notes_json.py',
    'scripts\inject_notes.py', 'scripts\export_docx.py',
    'scripts\workflow_state.py', 'tests\smoke_test.py',
    '.github\workflows\validate.yml'
)

foreach ($relative in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $relative))) {
        throw "Missing required file: $relative"
    }
}

$skill = Get-Content -Raw -LiteralPath (Join-Path $root 'SKILL.md')
if ($skill -notmatch '(?s)^---\s*\r?\nname:\s*university-ppt-notes\s*\r?\ndescription:.+?\r?\n---') {
    throw 'SKILL.md frontmatter is invalid.'
}
foreach ($term in @('ppt-speech-writer', 'humanize', '用户确认前', '不得缺页', '停止修改')) {
    if ($skill -notmatch [regex]::Escape($term)) {
        throw "SKILL.md is missing core rule: $term"
    }
}

$rules = Get-Content -Raw -LiteralPath (Join-Path $root 'references\authoring-rules.md')
foreach ($band in @('100—110字', '110—130字', '130—160字', '160—190字', '35—45字')) {
    if ($rules -notmatch [regex]::Escape($band)) {
        throw "Authoring rules are missing word band: $band"
    }
}

$guided = Get-Content -Raw -LiteralPath (Join-Path $root 'references\guided-workflow.md')
foreach ($term in @('全讲分析报告', '预期页码集合', '没有缺页、重页或跳页', '才一次性写入累计稿')) {
    if ($guided -notmatch [regex]::Escape($term)) {
        throw "Guided workflow is missing invariant: $term"
    }
}

$benchmarks = Get-Content -Raw -LiteralPath (Join-Path $root 'references\quality-benchmarks.md')
if ($benchmarks -notmatch '不是禁用词表' -or $benchmarks -notmatch '按需') {
    throw 'Quality benchmarks must remain an optional diagnostic reference.'
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
if ([regex]::Matches($example, '(?m)^## 类型[^：\r\n]*：').Count -ne 12) {
    throw 'Page-type examples must contain twelve labeled types.'
}

$pythonScripts = @(
    'scripts\build_notes_json.py', 'scripts\inject_notes.py',
    'scripts\export_docx.py', 'scripts\workflow_state.py'
)
foreach ($relative in $pythonScripts) {
    & $PythonExecutable -m py_compile (Join-Path $root $relative)
    if ($LASTEXITCODE -ne 0) { throw "Python compile failed: $relative" }
}

& $PythonExecutable (Join-Path $root 'tests\smoke_test.py') | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'End-to-end smoke test failed.' }

[pscustomobject]@{
    package = 'university-ppt-notes'
    required_files = $required.Count
    example_types = 12
    fixture_pages = 5
    audit_issues = 0
    smoke_test = 'passed'
    status = 'passed'
} | ConvertTo-Json -Compress
