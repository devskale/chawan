# Test Websites for img-ascii Validation

Sites chosen for: image variety (photos, icons, logos, gradients, SVGs),
layout complexity, and real-world CSS rendering.

## Direct Image URLs (standalone viewing)

| URL | What it tests |
|-----|---------------|
| `https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/PNG_transparency_demonstration_1.png/280px-PNG_transparency_demonstration_1.png` | PNG with transparency |
| `https://upload.wikimedia.org/wikipedia/commons/thumb/c/c3/ASF-16x16.svg/128px-ASF-16x16.svg.png` | Small icon (PNG) |
| `https://www.gstatic.com/images/branding/googlelogo/2x/googlelogo_color_272x92dp.png` | Logo with transparency |
| `https://upload.wikimedia.org/wikipedia/commons/thumb/a/a7/Camponotus_flavomarginatus_ant.jpg/320px-Camponotus_flavomarginatus_ant.jpg` | JPEG photo |
| `https://upload.wikimedia.org/wikipedia/commons/thumb/3/3a/Cat03.jpg/300px-Cat03.jpg` | JPEG photo (cat) |
| `https://raw.githubusercontent.com/nicedoc/nicedoc.io/master/assets/images/og.png` | Web screenshot |

## HTML Pages with Inline Images

| URL | What it tests |
|-----|---------------|
| `https://example.org` | Minimal page, no images (baseline) |
| `https://www.wikipedia.org` | Many small logo/icon images, SVGs |
| `https://en.wikipedia.org/wiki/Main_Page` | Mixed content: photos, icons, thumbnails, SVG logos |
| `https://news.ycombinator.com` | Text-heavy, tiny 1px spacer images |
| `https://lite.duckduckgo.com/lite` | Text search with small icons |
| `https://info.cern.ch` | Historic page, simple layout, small image |
| `https://motherfuckingwebsite.com` | Minimalist HTML, no images (baseline) |
| `https://catfact.ninja` | API-style page with an image |
| `https://sourcehut.org` | Clean layout, small logo |
| `https://git.sr.ht/~bptato/chawan` | Chawan's own page — relevant screenshots |

## Pages with Large Images

| URL | What it tests |
|-----|---------------|
| `https://apod.nasa.gov/apod/astropix.html` | Large daily astronomy photo |
| `https://unsplash.com` | Grid of large photographs |

## SVG-Heavy Pages

| URL | What it tests |
|-----|---------------|
| `https://www.rust-lang.org` | Inline SVGs, logos, icons |
| `https://nim-lang.org` | Inline SVGs in documentation |
| `https://archlinux.org` | SVG logo, simple layout |

## Edge Cases

| URL | What it tests |
|-----|---------------|
| `data:text/html,<img%20src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAFklEQVQYV2P8z8BQz0BFwMgwqsBiIJgYAnMUjPTzTq1AAAAAElFTkSuQmCC">` | 1×1 pixel PNG via data URI |
| `data:text/html,<img%20src="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' width='100' height='100'><rect fill='red' width='50' height='50'/><rect fill='blue' x='50' width='50' height='50'/></svg>">` | Inline SVG (red/blue checkerboard) |
| `data:text/html,<table><tr><td><img%20src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAKklEQVR4Ae3BAQ0AAADCoPdPbQ43oAAAAAAAAAAAAAAAAAAAAAAAAOBqHCAAATgo7J8AAAAASUVORK5CYII="></td><td>Hello</td></tr></table>` | Image in table cell beside text |
