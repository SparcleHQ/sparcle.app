#!/usr/bin/env python3
"""Transform download.astro from per-platform Install buttons to tabbed platform selector."""
import re
import sys

with open('src/pages/download.astro', 'r') as f:
    content = f.read()

# --- SVG icons for tabs ---
APPLE_SVG = '<svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/></svg>'
LINUX_SVG = '<svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M12.504 0c-.155 0-.315.008-.48.021-4.226.333-3.105 4.807-3.17 6.298-.076 1.092-.3 1.953-1.05 3.02-.885 1.051-2.127 2.75-2.716 4.521-.278.832-.41 1.684-.287 2.489a2.1 2.1 0 0 0-.084-.006c-.393 0-.777.158-1.048.473-.611.71-.354 1.884.482 2.497-.184.373-.27.77-.27 1.163 0 .63.259 1.248.867 1.687-.186.37-.275.758-.275 1.142 0 .838.537 1.591 1.541 1.846.305 1.166 1.451 2.344 2.527 2.344.348 0 .685-.113.978-.349.328.24.729.349 1.137.349.844 0 1.535-.479 1.879-1.219.417.102.862.155 1.316.155.455 0 .9-.054 1.316-.155.344.74 1.035 1.219 1.879 1.219.408 0 .809-.109 1.137-.349.293.236.63.349.978.349 1.076 0 2.222-1.178 2.527-2.344 1.004-.255 1.541-1.008 1.541-1.846 0-.384-.089-.771-.275-1.142.608-.439.867-1.057.867-1.687 0-.393-.086-.79-.27-1.163.836-.613 1.093-1.787.482-2.497-.271-.315-.655-.473-1.048-.473-.029 0-.057.003-.084.006.123-.805-.009-1.657-.287-2.489-.589-1.771-1.831-3.47-2.716-4.521-.75-1.067-.974-1.928-1.05-3.02-.065-1.491 1.056-5.965-3.17-6.298A5.1 5.1 0 0 0 12.504 0z"/></svg>'
WIN_SVG = '<svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M0 3.449L9.75 2.1v9.451H0m10.949-9.602L24 0v11.4H10.949M0 12.6h9.75v9.451L0 20.699M10.949 12.6H24V24l-12.9-1.801"/></svg>'
COPY_SVG = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>'


def copy_btn(cmd):
    # For the onclick, we need to handle the HTML entity &amp; properly
    # The clipboard should get the actual & character
    clipboard_cmd = cmd.replace('&amp;', '&')
    escaped = clipboard_cmd.replace("'", "\\'")
    return (
        f'<button class="dl-copy-btn" onclick="navigator.clipboard.writeText(\'{escaped}\');'
        f"this.querySelector('span').textContent='Copied!';"
        f"setTimeout(()=>this.querySelector('span').textContent='Copy',1500)\""
        f' title="Copy to clipboard">\n'
        f'                    {COPY_SVG}\n'
        f'                    <span>Copy</span>\n'
        f'                  </button>'
    )


def make_tabs_section(mac_cmd, linux_cmd, win_cmd, mac_note, linux_note, win_note):
    return (
        f'<div class="download-section">\n'
        f'              <div class="dl-tabs">\n'
        f'                <button class="dl-tab dl-tab--active" data-platform="macos">\n'
        f'                  {APPLE_SVG}\n'
        f'                  macOS\n'
        f'                </button>\n'
        f'                <button class="dl-tab" data-platform="linux">\n'
        f'                  {LINUX_SVG}\n'
        f'                  Linux\n'
        f'                </button>\n'
        f'                <button class="dl-tab" data-platform="windows">\n'
        f'                  {WIN_SVG}\n'
        f'                  Windows\n'
        f'                </button>\n'
        f'              </div>\n'
        f'              <div class="dl-panel" data-platform="macos">\n'
        f'                <p class="dl-cmd-hint">Run in Terminal &middot; Apple Silicon &amp; Intel</p>\n'
        f'                <div class="dl-code-block">\n'
        f'                  <code>{mac_cmd}</code>\n'
        f'                  {copy_btn(mac_cmd)}\n'
        f'                </div>\n'
        f'                <p class="dl-cmd-note">{mac_note}</p>\n'
        f'              </div>\n'
        f'              <div class="dl-panel" data-platform="linux" hidden>\n'
        f'                <p class="dl-cmd-hint">Run in Terminal &middot; x86_64 &amp; ARM64</p>\n'
        f'                <div class="dl-code-block">\n'
        f'                  <code>{linux_cmd}</code>\n'
        f'                  {copy_btn(linux_cmd)}\n'
        f'                </div>\n'
        f'                <p class="dl-cmd-note">{linux_note}</p>\n'
        f'              </div>\n'
        f'              <div class="dl-panel" data-platform="windows" hidden>\n'
        f'                <p class="dl-cmd-hint">Run in PowerShell &middot; x86_64</p>\n'
        f'                <div class="dl-code-block">\n'
        f'                  <code>{win_cmd}</code>\n'
        f'                  {copy_btn(win_cmd)}\n'
        f'                </div>\n'
        f'                <p class="dl-cmd-note">{win_note}</p>\n'
        f'              </div>\n'
        f'            </div>'
    )


# --- Build Personal and Enterprise sections ---
personal_tabs = make_tabs_section(
    mac_cmd='curl -fsSL https://sparcle.app/install.sh | sh',
    linux_cmd='curl -fsSL https://sparcle.app/install.sh | sh',
    win_cmd='irm https://sparcle.app/install.ps1 | iex',
    mac_note='Downloads, installs to /Applications, and launches Bolt',
    linux_note='Same script, auto-detects Linux &middot; installs AppImage to ~/.local/bin',
    win_note='Marks app as trusted &middot; downloads, installs, and launches Bolt',
)

enterprise_tabs = make_tabs_section(
    mac_cmd='curl -fsSL https://sparcle.app/install.sh | sh -s -- trial',
    linux_cmd='curl -fsSL https://sparcle.app/install.sh | sh -s -- trial',
    win_cmd='&amp; ([scriptblock]::Create((irm https://sparcle.app/install.ps1))) trial',
    mac_note='Downloads, installs to /Applications, and launches Bolt Enterprise',
    linux_note='Same script, auto-detects Linux &middot; installs AppImage to ~/.local/bin',
    win_note='Marks app as trusted &middot; downloads, installs, and launches Bolt Enterprise',
)

# --- Replace Personal download-section ---
personal_pattern = (
    r'(Your own personal AI assistant\n'
    r'              </li>\n'
    r'            </ul>\n)'
    r'\n'
    r'            <div class="download-section">.*?'
    r'</div>\n'
    r'            </div>\n'
    r'          </div>\n'
    r'\n'
    r'          <!-- ── Enterprise Trial Edition ── -->'
)
personal_replacement = (
    r'\1'
    '\n'
    '            ' + personal_tabs + '\n'
    '          </div>\n'
    '\n'
    '          <!-- ── Enterprise Trial Edition ── -->'
)
content_new = re.sub(personal_pattern, personal_replacement, content, count=1, flags=re.DOTALL)

if content_new == content:
    print("ERROR: Personal pattern did not match!")
    sys.exit(1)
print("OK: Personal section replaced")
content = content_new

# --- Replace Enterprise download-section ---
enterprise_pattern = (
    r'(Instant demo mode &mdash; preview with sample data\n'
    r'              </li>\n'
    r'            </ul>\n)'
    r'\n'
    r'            <div class="download-section">.*?'
    r'</div>\n'
    r'            </div>\n'
    r'          </div>\n'
    r'        </div>\n'
    r'\n'
    r'      <!-- FAQ -->'
)
enterprise_replacement = (
    r'\1'
    '\n'
    '            ' + enterprise_tabs + '\n'
    '          </div>\n'
    '        </div>\n'
    '\n'
    '      <!-- FAQ -->'
)
content_new = re.sub(enterprise_pattern, enterprise_replacement, content, count=1, flags=re.DOTALL)

if content_new == content:
    print("ERROR: Enterprise pattern did not match!")
    sys.exit(1)
print("OK: Enterprise section replaced")
content = content_new

# --- Replace CSS: remove dl-row styles, add dl-tabs styles ---
old_css = """  .dl-row {
    display: flex;
    align-items: center;
    gap: 1rem;
    padding: 0.75rem 0;
  }

  .dl-row + .dl-row {
    border-top: 1px solid var(--border-default);
  }

  .dl-row-label {
    display: flex;
    align-items: center;
    gap: 0.6rem;
    min-width: 110px;
    flex-shrink: 0;
  }

  .dl-row-links {
    display: flex;
    gap: 0.5rem;
    flex-wrap: wrap;
    flex: 1;
    justify-content: flex-end;
  }

  .dl-platform-icon {
    width: 36px;
    height: 36px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 8px;
    background: rgba(59, 130, 246, 0.1);
    color: var(--brand-primary, #3b82f6);
    flex-shrink: 0;
  }

  .dl-platform-name {
    font-size: 0.8rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: var(--text-body);
  }

  .dl-link {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    padding: 0.55rem 1.1rem;
    font-size: 0.85rem;
    font-weight: 600;
    color: var(--text-body);
    border: 1px solid var(--border-default);
    border-radius: 8px;
    text-decoration: none;
    transition: all var(--transition-fast);
  }

  .dl-link:hover {
    color: #fff;
    border-color: var(--brand-primary, #3b82f6);
    background: rgba(59, 130, 246, 0.15);
  }

  .dl-link--primary {
    background: var(--brand-primary, #3b82f6);
    border-color: var(--brand-primary, #3b82f6);
    color: #fff;
  }

  .dl-link--primary:hover {
    background: var(--brand-primary-hover, #2563eb);
    border-color: var(--brand-primary-hover, #2563eb);
  }

  .dl-link--disabled {
    opacity: 0.4;
    cursor: not-allowed;
    pointer-events: none;
  }

  .dl-coming-soon {
    font-size: 0.75rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.12em;
    color: var(--brand-primary, #3b82f6);
    margin: 0 0 0.25rem;
  }

  /* Expandable install command panel */
  .dl-cmd {
    padding: 0.75rem 0 0.25rem;
  }"""

new_css = """  /* Platform tab selector */
  .dl-tabs {
    display: flex;
    border-radius: 10px;
    overflow: hidden;
    border: 1px solid var(--border-default);
  }

  .dl-tab {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
    padding: 0.7rem 1rem;
    font-size: 0.82rem;
    font-weight: 600;
    color: var(--text-muted, #888);
    background: transparent;
    border: none;
    border-right: 1px solid var(--border-default);
    cursor: pointer;
    transition: all var(--transition-fast);
    font-family: inherit;
  }

  .dl-tab:last-child {
    border-right: none;
  }

  .dl-tab:hover {
    color: var(--text-body);
    background: rgba(59, 130, 246, 0.05);
  }

  .dl-tab--active {
    color: #fff;
    background: #16a34a;
  }

  .dl-tab--active:hover {
    background: #15803d;
  }

  /* Platform command panel */
  .dl-panel {
    padding: 1rem 0 0.25rem;
  }"""

if old_css not in content:
    print("ERROR: Old CSS pattern not found!")
    sys.exit(1)
content = content.replace(old_css, new_css, 1)
print("OK: CSS dl-row -> dl-tabs replaced")

# Remove remaining old CSS (install button, platform-arch, media query for dl-row)
old_css2 = """  /* Install button */
  .dl-link--install {
    background: #16a34a;
    border-color: #16a34a;
    color: #fff;
    cursor: pointer;
    font-family: inherit;
  }

  .dl-link--install:hover,
  .dl-link--active {
    background: #15803d;
    border-color: #15803d;
    color: #fff;
  }

  .dl-platform-arch {
    font-size: 0.7rem;
    color: var(--text-muted, #888);
    font-weight: 400;
  }

  @media (max-width: 480px) {
    .dl-row {
      flex-direction: column;
      align-items: flex-start;
      gap: 0.5rem;
    }
    .dl-row-links {
      justify-content: flex-start;
      width: 100%;
    }
  }"""

new_css2 = """  @media (max-width: 480px) {
    .dl-tabs {
      flex-direction: column;
    }
    .dl-tab {
      border-right: none;
      border-bottom: 1px solid var(--border-default);
    }
    .dl-tab:last-child {
      border-bottom: none;
    }
  }"""

if old_css2 not in content:
    print("ERROR: Old CSS2 pattern not found!")
    sys.exit(1)
content = content.replace(old_css2, new_css2, 1)
print("OK: CSS install/arch/media replaced")

# --- Add auto-detect script before </BaseLayout> ---
script = """
<script is:inline>
  (function() {
    function detectPlatform() {
      var ua = navigator.userAgent || '';
      if (ua.indexOf('Win') !== -1) return 'windows';
      if (ua.indexOf('Linux') !== -1) return 'linux';
      return 'macos';
    }

    function selectTab(section, platform) {
      section.querySelectorAll('.dl-tab').forEach(function(t) {
        t.classList.toggle('dl-tab--active', t.dataset.platform === platform);
      });
      section.querySelectorAll('.dl-panel').forEach(function(p) {
        p.hidden = p.dataset.platform !== platform;
      });
    }

    document.addEventListener('DOMContentLoaded', function() {
      var platform = detectPlatform();
      document.querySelectorAll('.download-section').forEach(function(section) {
        selectTab(section, platform);
        section.querySelectorAll('.dl-tab').forEach(function(tab) {
          tab.addEventListener('click', function() {
            selectTab(section, tab.dataset.platform);
          });
        });
      });
    });
  })();
</script>

"""

if '</BaseLayout>' not in content:
    print("ERROR: </BaseLayout> not found!")
    sys.exit(1)
content = content.replace('</BaseLayout>', script + '</BaseLayout>', 1)
print("OK: Script added before </BaseLayout>")

with open('src/pages/download.astro', 'w') as f:
    f.write(content)

print("\nAll transformations complete!")
