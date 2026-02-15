---
name: serve-jekyll
description: Serve Jekyll site accessible locally and via Playwright. Use when the user asks to browse the Jekyll site, preview the website, or access the Jekyll server with Playwright.
allowed-tools: Bash(./jekyll_serve_dev.sh, bundle exec*, ss *), mcp__playwright__browser_*
---

# Serve Jekyll Site

This skill starts the Jekyll development server for the Cyberknight Websites corporate site.

## Quick Start

```bash
./jekyll_serve_dev.sh
```

The server will be accessible at: `http://127.0.0.1:4000`

## Configuration Details

### Network Binding
The Jekyll server binds to `0.0.0.0:4000` to allow both local and Playwright access:
- **Host**: `0.0.0.0` - Accepts connections from all interfaces
- **Port**: `4000` - Default development port

## Accessing via Playwright

The Playwright MCP server runs in a Docker container with `--network host` mode, giving it direct access to the host's network stack.

### URL Mapping

**Important**: When the user references `http://council-test.cyberknight-websites.com/`, you should navigate to `http://127.0.0.1:4000/` instead.

- **User-facing URL**: `http://council-test.cyberknight-websites.com/` (VPN-accessible test URL for the user)
- **Internal server URL**: `http://127.0.0.1:4000/` (what Playwright should actually use)

Both URLs point to the same Jekyll development server, but Playwright must use the internal localhost address.

### Direct Access URL

Playwright should access the Jekyll server using:
```
http://127.0.0.1:4000
```

**Why this works**:
- Playwright container uses `--network host` mode (configured in `~/.claude.json`)
- With host networking, `127.0.0.1` inside the container refers to the host's localhost
- This allows direct access to Jekyll without any network translation

### Available Playwright Tools

Once navigated, you can:
- Take snapshots with `mcp__playwright__browser_snapshot`
- Take screenshots with `mcp__playwright__browser_take_screenshot`
- Click elements with `mcp__playwright__browser_click`
- Fill forms with `mcp__playwright__browser_fill_form`
- Evaluate JavaScript with `mcp__playwright__browser_evaluate`

## Script Arguments

```bash
./jekyll_serve_dev.sh [HOST] [PORT]
```

- **HOST**: Binding host (default: 0.0.0.0)
- **PORT**: Server port (default: 4000)

## Testing

### From Local Machine
```bash
curl http://127.0.0.1:4000/
curl http://localhost:4000/
```

### From Playwright
```
mcp__playwright__browser_navigate(url="http://127.0.0.1:4000/")
mcp__playwright__browser_snapshot()
```

## Troubleshooting

### Port 4000 Already in Use
```bash
# Find process
ss -tlnp | grep :4000

# Stop background Jekyll
/tasks stop <task-id>
```

### Playwright Cannot Connect
- **Check**: Jekyll server is running (`ss -tlnp | grep :4000`)
- **Check**: Playwright MCP uses `--network host` (configured in `~/.claude.json`)
- **Check**: Using correct URL format `http://127.0.0.1:4000/`
- **Check**: Restart Claude Code after modifying MCP configuration

## Background Task Management

To run in background:
```bash
# Start in background (use run_in_background parameter in Bash tool)
./jekyll_serve_dev.sh

# Stop later
/tasks stop <task-id>
```

## Complete Workflow Examples

### Example 1: Start Jekyll and Access with Playwright

**User Request:** "Start the Jekyll server and open it in Playwright"

**Actions:**
1. Run startup script:
   ```bash
   ./jekyll_serve_dev.sh
   ```
   (Use run_in_background parameter for background execution)

2. Navigate with Playwright:
   ```
   mcp__playwright__browser_navigate(url="http://127.0.0.1:4000/")
   ```

3. Take snapshot to show the page:
   ```
   mcp__playwright__browser_snapshot()
   ```

4. Report to user: "Jekyll server is running and accessible at http://127.0.0.1:4000/"

### Example 2: Visit Specific Page

**User Request:** "Visit the about page"

**Actions:**
1. Navigate to page:
   ```
   mcp__playwright__browser_navigate(url="http://127.0.0.1:4000/about")
   ```

2. Take snapshot:
   ```
   mcp__playwright__browser_snapshot()
   ```

3. Report to user: "Navigated to the about page"

### Example 3: URL Mapping

**User Request:** "Navigate to http://council-test.cyberknight-websites.com/pricing"

**Actions:**
1. Map the URL to internal address and navigate:
   ```
   mcp__playwright__browser_navigate(url="http://127.0.0.1:4000/pricing")
   ```
   (Note: council-test.cyberknight-websites.com → 127.0.0.1:4000)

2. Take snapshot:
   ```
   mcp__playwright__browser_snapshot()
   ```

3. Report to user: "Navigated to the pricing page"

## Security Notes

- Jekyll binds to `0.0.0.0:4000` for accessibility
- Port 4000 is accessible on all network interfaces but is non-standard
- Playwright MCP uses `--network host` for direct localhost access
- Development server - not for production use
