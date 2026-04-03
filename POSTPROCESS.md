# Sandbox HTML Post-Processing — Known Issues & Fixes

When HTML visualizations are emailed via Gmail and published to sandbox.wangreport.com,
Gmail corrupts the code in multiple ways. This doc lists every known issue so that
any session (Architect, Forge, or manual fix) can diagnose and repair broken pages.

## Gmail Corruption Issues (handled in email processor)

| Issue | Symptom | Fix |
|-------|---------|-----|
| `--` → en dash `–` (U+2013) | CSS custom properties don't work, white/broken background | Replace U+2013 with `--` |
| `*` → `-` at line start | CSS universal selector `* {}` broken | Replace `- {` with `* {` after `}` or `;` |
| Entity escaping | `<div>` becomes `&lt;div&gt;` | Unescape via `html.unescape()` |
| Auto-linkified URLs | `href="url"` becomes `<a href="url">url</a>` inside code | Strip `<a>` wrappers before unescaping |
| `<br style="font-size:inherit">` | Extra line breaks in output | Remove Gmail-specific br tags |
| Leading spaces in attributes | `href=" https://..."` breaks font loading | Remove spaces after `="` |
| Markdown backticks ` ``` ` | Visible artifacts in rendered page | Strip ` ```html ` and ` ``` ` |

## JavaScript Issues (handled in postprocess_html + manual /sandbox fix)

| Issue | Symptom | Fix |
|-------|---------|-----|
| JS collapsed to single line | **All charts/dynamic content missing.** Browser silently fails to parse. Node `--check` passes but browsers fail. | Add newlines after `;` and `}` in script blocks |
| Template literals after Gmail | `${var}` appears literally in output instead of evaluated | Rewrite to string concatenation: `"text " + var + " more"` |
| Arrow functions | May fail in older Safari | Rewrite to `function(){}` |
| `const`/`let` in strict contexts | Edge cases in some browsers | Use `var` for maximum compat |
| `event.target` in onclick handlers | `showTab(id)` uses implicit `event` global — fails in Safari | Use `querySelector` to find the clicked tab by ID match |
| Single render failure kills all | One broken chart = blank page | Wrap each `renderX()` call in `try-catch` |
| `innerHTML +=` on SVG | Works in Chrome, may fail in Safari for complex SVGs | Use `createElementNS` and `appendChild` for SVG elements |

## CSS Issues

| Issue | Symptom | Fix |
|-------|---------|-----|
| `opacity: 0` + IntersectionObserver | Sections permanently hidden (scroll-reveal) | Set `opacity: 1; transform: none;` |
| `body::before` grain overlay z-index | High z-index overlay blocks interaction | Lower z-index or set `pointer-events: none` |
| `@import url()` at top of `<style>` | Font loading blocks all CSS | Move to `<link>` tag if possible |

## How `/sandbox fix N` Works

1. Architect reads the file and checks for all issues above
2. Fixes what it can with targeted edits
3. If JS is too broken, regenerates the file: keeps ALL data/content, rewrites the code
4. Key rule when regenerating: use `var`, regular functions, string concatenation, try-catch
5. Commits and pushes — GitHub Action deploys in ~30s

## How to Verify a Fix

```bash
# Headless Chrome screenshot (best way to verify without opening browser)
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --disable-gpu \
  --screenshot=/tmp/verify.png --window-size=390,2000 \
  "http://sandbox.wangreport.com/filename.html"

# Then read the screenshot to check rendering
```

## URL-Based Publishing (Preferred — Zero Mangling)

Instead of pasting HTML code into Gmail body, paste a **URL** to the published artifact:

| Source | URL Format | How it works |
|--------|-----------|-------------|
| Claude iOS "Publish" | `https://claude.site/artifacts/...` | Processor fetches raw HTML from URL |
| GitHub Gist | `https://gist.github.com/user/id` | Processor fetches raw gist content |

**Workflow:** Email `wangwithbot@gmail.com` with subject `sandbox: filename` and just the URL in the body.
The processor detects the URL, fetches the HTML directly (no Gmail encoding), and publishes it.

This completely bypasses all Gmail corruption issues listed above.

## Root Cause

Gmail is fundamentally unreliable for transporting HTML code. URL-based publishing
(claude.site or gist) is the preferred path. HTML-in-body is the fallback with
post-processing fixes applied. See memory:
`~/.claude/projects/-Users-harrywang--openclaw/memory/feedback_gmail_html_transport.md`
