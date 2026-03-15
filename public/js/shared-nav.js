/**
 * shared-nav.js — Sparcle.LLC
 *
 * Injects the shared navbar and footer into every page, making the site
 * behave like a single-page app for consistent layout, theme toggle,
 * and navigation across all HTML pages.
 *
 * Usage: add  <script src="js/shared-nav.js"></script>  to every page,
 * and make sure the <head> has the anti-flash snippet (see below).
 *
 * Anti-flash <head> snippet (copy into every page's <head>):
 *   <script>
 *     (function(){var t=localStorage.getItem('theme')||'dark';
 *     document.documentElement.setAttribute('data-theme',t);})();
 *   </script>
 */

(function () {
    'use strict';

    /* ------------------------------------------------------------------
       DETECT PAGE CONTEXT
       ------------------------------------------------------------------ */
    var path = window.location.pathname;
    var isHome = (path === '/' || path === '/index.html' || path === '');

    /** Returns an href that works from any page */
    function href(hash) {
        return isHome ? hash : ('/' + hash);
    }

    /** Returns 'active' class string if the given page name matches */
    function activeClass(page) {
        if (page === 'research' && path.indexOf('research') !== -1) return ' nav-active';
        if (page === 'pricing' && path.indexOf('pricing') !== -1) return ' nav-active';
        if (page === 'crisis' && path.indexOf('/crisis') !== -1) return ' nav-active';
        if (page === 'solution' && path.indexOf('/solution') !== -1) return ' nav-active';
        if (page === 'why-sparcle' && path.indexOf('/why-sparcle') !== -1) return ' nav-active';
        if (page === 'products' && (path.indexOf('/products') !== -1 || path.indexOf('/bolt') !== -1)) return ' nav-active';
        return '';
    }

    /* ------------------------------------------------------------------
       NAVBAR HTML
       ------------------------------------------------------------------ */
    var navHTML = [
        '<nav class="navbar" id="navbar">',
        '  <div class="nav-logo">',
        '    <a href="/" style="display:flex;align-items:center;gap:0.75rem;">',
        '      <img src="/images/sparkle-icon.svg" alt="Sparcle" width="32" height="32" style="width:32px;height:32px;">',
        '      <span style="font-size:1.25rem;font-weight:700;color:var(--text-heading);">Sparcle</span>',
        '    </a>',
        '  </div>',
        '  <ul class="nav-menu" id="navMenu">',
        '    <li><a href="/crisis" class="nav-link' + activeClass('crisis') + '">The Crisis</a></li>',
        '    <li><a href="/solution" class="nav-link' + activeClass('solution') + '">Our Solution</a></li>',
        '    <li><a href="/why-sparcle" class="nav-link' + activeClass('why-sparcle') + '">Why Sparcle</a></li>',
        '    <li><a href="/products.html" class="nav-link' + activeClass('products') + '">Products</a></li>',
        '    <li><a href="/pricing.html#bolt" class="nav-link' + activeClass('pricing') + '">Pricing</a></li>',
        '  </ul>',
        '  <div class="nav-controls">',
        '    <button class="theme-toggle" id="themeToggle" aria-label="Toggle theme">',
        '      <!-- moon (shown in dark mode) -->',
        '      <svg class="icon-moon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">',
        '        <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/>',
        '      </svg>',
        '      <!-- sun (shown in light mode) -->',
        '      <svg class="icon-sun" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">',
        '        <circle cx="12" cy="12" r="5"/>',
        '        <line x1="12" y1="1" x2="12" y2="3"/>',
        '        <line x1="12" y1="21" x2="12" y2="23"/>',
        '        <line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/>',
        '        <line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/>',
        '        <line x1="1" y1="12" x2="3" y2="12"/>',
        '        <line x1="21" y1="12" x2="23" y2="12"/>',
        '        <line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/>',
        '        <line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/>',
        '      </svg>',
        '    </button>',
        '    <a href="' + href('#contact') + '" class="btn btn-primary btn-sm">Let\'s Talk</a>',
        '  </div>',
        '  <!-- Mobile hamburger -->',
        '  <button class="nav-toggle" id="navToggle" aria-label="Toggle navigation" aria-expanded="false">',
        '    <span></span><span></span><span></span>',
        '  </button>',
        '</nav>'
    ].join('\n');

    /* ------------------------------------------------------------------
       FOOTER HTML
       ------------------------------------------------------------------ */
    var footerHTML = [
        '<footer class="footer">',
        '  <div class="container">',
        '    <div class="footer-grid">',
        '      <div class="footer-brand">',
        '        <div style="display:flex;align-items:center;gap:0.75rem;margin-bottom:1rem;">',
        '          <img src="/images/sparkle-icon.svg" alt="" style="height:32px;">',
        '          <span style="font-size:1.25rem;font-weight:700;">Sparcle</span>',
        '        </div>',
        '        <p>Building unified intelligence for the modern enterprise.</p>',
        '      </div>',
        '      <div class="footer-col">',
        '        <h5>Products</h5>',
        '        <ul>',
        '          <li><a href="/products.html" style="display:inline-flex;align-items:center;gap:0.4rem;"><img src="/images/bolt-logo.svg" alt="" width="16" height="16" style="border-radius:3px;">Bolt</a></li>',
        '          <li><a href="/products/bolt-data.html" style="display:inline-flex;align-items:center;gap:0.4rem;"><img src="/images/aeira-logo.svg" alt="" width="16" height="16" style="border-radius:3px;">Aeira</a></li>',
        '        </ul>',
        '      </div>',
        '      <div class="footer-col">',
        '        <h5>Resources</h5>',
        '        <ul>',
        '          <li><a href="/research.html">Research &amp; Whitepaper</a></li>',
        '          <li><a href="/media/Bolt_Strategic_Vision.pdf" target="_blank">Strategic Vision</a></li>',
        '          <li><a href="https://sparcle.app/whitepaper-print.html" target="_blank">Full Whitepaper</a></li>',
        '        </ul>',
        '      </div>',
        '      <div class="footer-col">',
        '        <h5>Company</h5>',
        '        <ul>',
        '          <li><a href="' + href('#contact') + '">Contact</a></li>',
        '          <li><a href="/privacy">Privacy Policy</a></li>',
        '          <li><a href="/terms">Terms of Service</a></li>',
        '        </ul>',
        '      </div>',
        '    </div>',
        '    <div class="footer-bottom">',
        '      <span>&copy; 2026 Sparcle, LLC. All rights reserved.</span>',
        '      <span class="footer-legal">Patents Pending: US 63/951,662 &bull; 63/952,801 &bull; 63/952,804</span>',
        '    </div>',
        '  </div>',
        '</footer>'
    ].join('\n');

    /* ------------------------------------------------------------------
       INJECT NAV
       Inserts before the first child of <body>  (or replaces existing #navbar)
       ------------------------------------------------------------------ */
    var existingNav = document.getElementById('navbar');
    if (existingNav) {
        existingNav.outerHTML = navHTML;
    } else {
        document.body.insertAdjacentHTML('afterbegin', navHTML);
    }

    /* ------------------------------------------------------------------
       INJECT FOOTER
       Replaces existing <footer> or appends one.
       ------------------------------------------------------------------ */
    var existingFooter = document.querySelector('footer.footer');
    if (existingFooter) {
        existingFooter.outerHTML = footerHTML;
    } else {
        document.body.insertAdjacentHTML('beforeend', footerHTML);
    }

    /* ------------------------------------------------------------------
       THEME INIT & TOGGLE
       ------------------------------------------------------------------ */
    (function initTheme() {
        var root = document.documentElement;
        // Apply saved or system preference immediately (anti-flash)
        var saved = localStorage.getItem('theme');
        var systemDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
        root.setAttribute('data-theme', saved || (systemDark ? 'dark' : 'light'));

        var btn = document.getElementById('themeToggle');
        if (btn) {
            btn.addEventListener('click', function () {
                var current = root.getAttribute('data-theme') || 'dark';
                var next = current === 'dark' ? 'light' : 'dark';
                root.setAttribute('data-theme', next);
                localStorage.setItem('theme', next);
            });
        }

        // Sync with OS changes (only if user hasn't pinned a preference)
        window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', function (e) {
            if (!localStorage.getItem('theme')) {
                root.setAttribute('data-theme', e.matches ? 'dark' : 'light');
            }
        });
    }());

    /* ------------------------------------------------------------------
       NAVBAR SCROLL GLASS EFFECT
       ------------------------------------------------------------------ */
    window.addEventListener('scroll', function () {
        var nav = document.getElementById('navbar');
        if (nav) {
            nav.classList.toggle('scrolled', window.scrollY > 10);
        }
    }, { passive: true });

    /* ------------------------------------------------------------------
       MOBILE MENU TOGGLE
       ------------------------------------------------------------------ */
    (function initMobileMenu() {
        var toggle = document.getElementById('navToggle');
        var menu = document.getElementById('navMenu');
        if (!toggle || !menu) return;

        // Mark as initialized so main.js doesn't double-bind
        toggle.dataset.navInit = 'true';

        toggle.addEventListener('click', function () {
            var open = menu.classList.toggle('open');
            toggle.classList.toggle('open', open);
            toggle.setAttribute('aria-expanded', String(open));
        });

        // Close when clicking outside
        document.addEventListener('click', function (e) {
            if (!toggle.contains(e.target) && !menu.contains(e.target)) {
                menu.classList.remove('open');
                toggle.classList.remove('open');
                toggle.setAttribute('aria-expanded', 'false');
            }
        });

        // Close on nav link click
        menu.querySelectorAll('a.nav-link').forEach(function (link) {
            link.addEventListener('click', function () {
                menu.classList.remove('open');
                toggle.classList.remove('open');
                toggle.setAttribute('aria-expanded', 'false');
            });
        });
    }());

    /* Scrollspy removed — all nav links now go to dedicated pages */

}());
