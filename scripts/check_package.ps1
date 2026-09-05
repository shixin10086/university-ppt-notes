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
    'references\final-audit.md',
    'references\guided-workflow.md',
    'references\quality-benchmarks.md',
    'templates\notes-template.md',
    'templates\state-template.json',
    'examples\sample-notes.md',
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

$license = Get-Content -Raw -LiteralPath (Join-Path $root 'LICENSE')
if ($license -notmatch '^MIT License' -or $license -notmatch 'Copyright \(c\) 2026 余京泽') {
    throw 'LICENSE is missing the expected MIT copyright notice.'
}

$auditJson = & (Join-Path $root 'scripts\audit_notes.ps1') `
    -NotesPath (Join-Path $root 'examples\sample-notes.md') `
    -ExpectedSlideCount 5
$audit = $auditJson | ConvertFrom-Json
if ($audit.issue_count -ne 0) {
    $audit.issues | ConvertTo-Json -Depth 5 | Write-Output
    throw 'Example notes failed audit.'
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
        --input (Join-Path $root 'examples\sample-notes.md') `
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
    example_pages = 5
    audit_issues = 0
    smoke_test = 'passed'
    status = 'passed'
} | ConvertTo-Json -Compress
