param(
    [Parameter(Mandatory = $true)]
    [string]$NotesPath,

    [string]$SlideExtractPath,

    [int]$ExpectedSlideCount = 0
)

$ErrorActionPreference = 'Stop'

function Get-LabeledBlock {
    param(
        [string]$Section,
        [string]$Label
    )

    $escaped = [regex]::Escape("【$Label】")
    $match = [regex]::Match(
        $Section,
        "(?s)$escaped\s*(.*?)(?=\r?\n\s*【|\r?\n\s*---|$)"
    )
    if (-not $match.Success) {
        return $null
    }
    return $match.Groups[1].Value.Trim()
}

function Add-Issue {
    param(
        [System.Collections.Generic.List[object]]$Issues,
        [int]$Page,
        [string]$Kind,
        [string]$Message
    )

    $Issues.Add([pscustomobject]@{
        page = $Page
        kind = $Kind
        message = $Message
    })
}

$notes = Get-Content -Raw -LiteralPath $NotesPath
$slides = @()
if ($SlideExtractPath) {
    $slideData = Get-Content -Raw -LiteralPath $SlideExtractPath | ConvertFrom-Json
    $slides = @($slideData.slides)
}
$headingMatches = [regex]::Matches($notes, '(?m)^## P(\d+)\s+(.+?)\s*$')
$issues = [System.Collections.Generic.List[object]]::new()
$records = [System.Collections.Generic.List[object]]::new()
$slideCount = if ($slides.Count -gt 0) { $slides.Count } elseif ($ExpectedSlideCount -gt 0) { $ExpectedSlideCount } else { $headingMatches.Count }

$rangeMatch = [regex]::Match($notes, '(?m)^#\s+.*?P(\d+)[—-]P(\d+).*$')
if ($rangeMatch.Success) {
    $rangeStart = [int]$rangeMatch.Groups[1].Value
    $rangeEnd = [int]$rangeMatch.Groups[2].Value
    if ($rangeStart -ne 1 -or $rangeEnd -ne $slideCount) {
        Add-Issue $issues 0 'document-range' "文档标题页码范围为P$('{0:D2}' -f $rangeStart)—P$('{0:D2}' -f $rangeEnd)，实际应为P01—P$('{0:D2}' -f $slideCount)。"
    }
}

if ($headingMatches.Count -ne $slideCount) {
    Add-Issue $issues 0 'page-count' "备稿标题数为$($headingMatches.Count)，预期页数为$slideCount。"
}

$seen = @{}
for ($index = 0; $index -lt $headingMatches.Count; $index++) {
    $heading = $headingMatches[$index]
    $page = [int]$heading.Groups[1].Value
    $title = $heading.Groups[2].Value.Trim()
    $start = $heading.Index + $heading.Length
    $end = if ($index + 1 -lt $headingMatches.Count) { $headingMatches[$index + 1].Index } else { $notes.Length }
    $section = $notes.Substring($start, $end - $start)

    if ($seen.ContainsKey($page)) {
        Add-Issue $issues $page 'duplicate-page' '页码重复。'
    }
    $seen[$page] = $true

    if ($page -ne ($index + 1)) {
        Add-Issue $issues $page 'page-order' "第$($index + 1)个页面标题写成了P$('{0:D2}' -f $page)。"
    }

    $slide = if ($slides.Count -gt 0) { $slides | Where-Object { [int]$_.slide -eq $page } | Select-Object -First 1 } else { $null }
    if ($slides.Count -gt 0 -and $null -eq $slide) {
        Add-Issue $issues $page 'missing-slide' '在PPT提取结果中找不到对应页面。'
    } elseif ($null -ne $slide) {
        $pptTitle = [string]$slide.title
        $normalizedTitle = $title -replace '^第[一二三四五六七八九十]+节[：:]\s*', ''
        $genericTitleAllowed = ($page -eq 1 -and $title -eq '封面') -or ($page -eq 2 -and $title -eq '目录')
        if (-not $genericTitleAllowed -and $title -ne $pptTitle -and $normalizedTitle -ne $pptTitle) {
            Add-Issue $issues $page 'title-mismatch' "备稿标题“${title}”与PPT标题“${pptTitle}”不一致。"
        }
    }

    $labels = @([regex]::Matches($section, '【([^】]+)】') | ForEach-Object { $_.Groups[1].Value })
    $format = 'unknown'
    $bodyLength = $null

    if ($labels -contains '开场') {
        $format = 'cover'
        $text = Get-LabeledBlock $section '开场'
        if ($text.Length -lt 150 -or $text.Length -gt 200) {
            Add-Issue $issues $page 'length' "开场为$($text.Length)字，应为150—200字。"
        }
    } elseif ($labels -contains '讲授说明') {
        $format = 'contents'
        $text = Get-LabeledBlock $section '讲授说明'
        if ($text.Length -lt 80 -or $text.Length -gt 120) {
            Add-Issue $issues $page 'length' "讲授说明为$($text.Length)字，应为80—120字，目录内容较多时允许写到100字以上。"
        }
    } elseif ($labels -contains '过渡') {
        $format = 'transition'
        $text = Get-LabeledBlock $section '过渡'
        if ($text.Length -lt 60 -or $text.Length -gt 90) {
            Add-Issue $issues $page 'length' "过渡为$($text.Length)字，应为60—90字。"
        }
    } elseif (($labels -contains '问题描述') -or ($labels -contains '思考重点') -or ($labels -contains '参考回答')) {
        $format = 'thinking'
        foreach ($required in @('问题描述', '思考重点', '参考回答')) {
            if ($labels -notcontains $required) {
                Add-Issue $issues $page 'format' "课堂思考页缺少【$required】。"
            }
        }
        $prompt = Get-LabeledBlock $section '问题描述'
        if ($null -ne $prompt -and $prompt -notmatch '请同学们.*思考') {
            Add-Issue $issues $page 'thinking-prompt' '问题描述没有明确提示同学们开始思考。'
        }
    } elseif ($labels -contains '观看提示') {
        $format = 'video'
        if ($labels.Count -ne 1) {
            Add-Issue $issues $page 'format' '视频页除【观看提示】外还出现了其他模块。'
        }
    } elseif (($labels -contains '引入') -or ($labels -contains '备稿') -or ($labels -contains '收束')) {
        $format = 'content'
        foreach ($required in @('引入', '备稿', '收束')) {
            if ($labels -notcontains $required) {
                Add-Issue $issues $page 'format' "普通内容页缺少【$required】。"
            }
        }

        $intro = Get-LabeledBlock $section '引入'
        $body = Get-LabeledBlock $section '备稿'
        $closing = Get-LabeledBlock $section '收束'
        $bodyLength = if ($null -eq $body) { $null } else { $body.Length }

        if ($null -ne $intro) {
            $sentenceCount = ([regex]::Matches($intro, '[。！？!?]')).Count
            if ($intro.Length -gt 60) {
                Add-Issue $issues $page 'length' "引入为$($intro.Length)字，超过60字。"
            }
            if ($sentenceCount -ne 1) {
                Add-Issue $issues $page 'sentence-count' "引入检测到$sentenceCount个句末标点，应为一句。"
            }
        }

        if ($null -ne $closing) {
            $sentenceCount = ([regex]::Matches($closing, '[。！？!?]')).Count
            if ($closing.Length -lt 35 -or $closing.Length -gt 45) {
                Add-Issue $issues $page 'length' "收束为$($closing.Length)字，应为35—45字。"
            }
            if ($sentenceCount -ne 1) {
                Add-Issue $issues $page 'sentence-count' "收束检测到$sentenceCount个句末标点，应为一句。"
            }
        }

        if ($null -ne $body -and ($body.Length -lt 60 -or $body.Length -gt 185)) {
            Add-Issue $issues $page 'length' "备稿正文为$($body.Length)字，超出60—185字总范围。"
        }
    } else {
        Add-Issue $issues $page 'format' '无法识别页面备稿格式。'
    }

    $records.Add([pscustomobject]@{
        page = $page
        title = $title
        format = $format
        body_length = $bodyLength
    })
}

foreach ($expectedPage in 1..$slideCount) {
    if (-not $seen.ContainsKey($expectedPage)) {
        Add-Issue $issues $expectedPage 'missing-page' '累计稿缺少这一页。'
    }
}

[pscustomobject]@{
    notes_path = (Resolve-Path -LiteralPath $NotesPath).Path
    slide_count = $slideCount
    note_page_count = $headingMatches.Count
    issue_count = $issues.Count
    issues = @($issues)
    pages = @($records)
} | ConvertTo-Json -Depth 6
