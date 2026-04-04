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
        if (page === 'download' && path.indexOf('/download') !== -1) return ' nav-active';
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
        '  <div class="nav-inner">',
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
        '    <li><a href="/download" class="nav-link' + activeClass('download') + '">Download</a></li>',
        '  </ul>',
        '  <div class="nav-controls">',
        '    <button class="theme-toggle" id="themeToggle" aria-label="Switch to dark theme" data-mode="auto">',
        '      <!-- half-filled circle: left=light, right=dark — auto/system theme -->',
        '      <svg class="icon-auto" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">',
        '        <path d="M12 3A9 9 0 0 0 12 21Z" fill="currentColor" stroke="none"/>',
        '        <circle cx="12" cy="12" r="9"/>',
        '      </svg>',
        '      <svg class="icon-moon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">',
        '        <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/>',
        '      </svg>',
        '      <!-- sun (light mode) -->',
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
        '    <a href="#" onclick="openContactModal(); return false;" class="btn btn-primary btn-sm">Let\'s Talk</a>',
        '  </div>',
        '  <!-- Mobile hamburger -->',
        '  <button class="nav-toggle" id="navToggle" aria-label="Toggle navigation" aria-expanded="false">',
        '    <span></span><span></span><span></span>',
        '  </button>',
        '  </div>',
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
        '        <a href="/" style="display:flex;align-items:center;gap:0.75rem;margin-bottom:1rem;text-decoration:none;color:inherit;">',
        '          <img src="/images/sparkle-icon.svg" alt="Sparcle" style="height:32px;">',
        '          <span style="font-size:1.25rem;font-weight:700;">Sparcle</span>',
        '        </a>',
        '        <p>Building unified intelligence for the modern enterprise.</p>',
        '      </div>',
        '      <div class="footer-col">',
        '        <h5>Products</h5>',
        '        <ul>',
        '          <li><a href="/products.html" style="display:inline-flex;align-items:center;gap:0.4rem;"><img src="/images/bolt-logo.svg" alt="" width="16" height="16" style="border-radius:3px;">Bolt</a></li>',
        '          <li><a href="/products.html#aeira" style="display:inline-flex;align-items:center;gap:0.4rem;"><img src="/images/aeira-logo.svg" alt="" width="16" height="16" style="border-radius:3px;">Aeira</a></li>',
        '        </ul>',
        '      </div>',
        '      <div class="footer-col">',
        '        <h5>Resources</h5>',
        '        <ul>',
        '          <li><a href="/research.html">Research &amp; Whitepaper</a></li>',
        '          <li><a href="/media/Bolt_Strategic_Vision.pdf" target="_blank">Strategic Vision</a></li>',
        '          <li><a href="https://sparcle.app/legacy/whitepaper-print.html" target="_blank">Full Whitepaper</a></li>',
        '        </ul>',
        '      </div>',
        '      <div class="footer-col">',
        '        <h5>Company</h5>',
        '        <ul>',
        '          <li><a href="#" onclick="openContactModal(); return false;">Contact</a></li>',
        '          <li><a href="/privacy">Privacy Policy</a></li>',
        '          <li><a href="/terms">Terms of Service</a></li>',
        '        </ul>',
        '      </div>',
        '    </div>',
        '    <div class="footer-bottom">',
        '      <span>&copy; 2026 Sparcle, LLC. All rights reserved.</span>',
        '      <span class="footer-legal">Patents Pending</span>',
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
    // Skip link must be first child for a11y — insert after nav injection
    if (!document.querySelector('.skip-link')) {
        var skip = document.createElement('a');
        skip.className = 'skip-link';
        skip.href = '#main-content';
        skip.textContent = 'Skip to main content';
        document.body.insertAdjacentElement('afterbegin', skip);
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
        var saved = localStorage.getItem('theme');
        var mode = (saved === 'dark' || saved === 'light') ? saved : 'auto';
        var labels = { auto: 'Switch to dark theme', dark: 'Switch to light theme', light: 'Use system theme' };
        var cycles = { auto: 'dark', dark: 'light', light: 'auto' };

        function applyMode(m) {
            if (m === 'auto') {
                var sysDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
                root.setAttribute('data-theme', sysDark ? 'dark' : 'light');
            } else {
                root.setAttribute('data-theme', m);
            }
        }

        function updateBtn(btn, m) {
            btn.setAttribute('data-mode', m);
            btn.setAttribute('aria-label', labels[m]);
        }

        applyMode(mode);

        var btn = document.getElementById('themeToggle');
        if (btn) {
            updateBtn(btn, mode);
            btn.addEventListener('click', function () {
                var current = btn.getAttribute('data-mode') || 'auto';
                var next = cycles[current];
                if (next === 'auto') {
                    localStorage.removeItem('theme');
                } else {
                    localStorage.setItem('theme', next);
                }
                applyMode(next);
                updateBtn(btn, next);
            });
        }

        // Sync with OS changes when in auto mode
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

    /* ------------------------------------------------------------------
       SHARED CONTACT MODAL
       Only inject if the page doesn't already have one (pricing/index have theirs)
       ------------------------------------------------------------------ */
    if (!document.getElementById('contactModalOverlay')) {
        var modalHTML = [
            '<div id="contactModalOverlay" class="contact-modal-overlay" role="dialog" aria-modal="true" aria-label="Contact form">',
            '  <div class="contact-modal">',
            '    <button class="contact-modal-close" onclick="closeContactModal()" aria-label="Close">&times;</button>',
            '    <h3 id="contactModalTitle">Get in Touch</h3>',
            '    <p class="modal-subtitle">We\'ll respond within one business day.</p>',
            '    <form id="contactForm" autocomplete="on">',
            '      <div id="contactFormFields">',
            '        <input type="hidden" id="contactInterest" name="interest" value="">',
            '        <div class="contact-form-group"><label for="contactName">Name</label><input type="text" id="contactName" name="name" required placeholder="Jane Smith" autocomplete="name"></div>',
            '        <div class="contact-form-group"><label for="contactEmail">Work Email</label><input type="email" id="contactEmail" name="email" required placeholder="jane@company.com" autocomplete="email"></div>',
            '        <div class="contact-form-group"><label for="contactCompany">Company</label><input type="text" id="contactCompany" name="company" placeholder="Acme Corp" autocomplete="organization"></div>',
            '        <div class="contact-form-group"><label for="contactTeamSize">Team Size</label><select id="contactTeamSize" name="teamSize"><option value="">Select\u2026</option><option value="1-10">1\u201310</option><option value="11-50">11\u201350</option><option value="51-200">51\u2013200</option><option value="201-500">201\u2013500</option><option value="500+">500+</option></select></div>',
            '        <button type="submit" id="contactSubmitBtn" class="contact-submit-btn">Send Request</button>',
            '      </div>',
            '      <div id="contactFormStatus" class="contact-form-status"></div>',
            '    </form>',
            '  </div>',
            '</div>'
        ].join('\n');
        document.body.insertAdjacentHTML('beforeend', modalHTML);

        // Bind form submit
        var contactForm = document.getElementById('contactForm');
        contactForm.addEventListener('submit', function(e) {
            e.preventDefault();
            var btn = document.getElementById('contactSubmitBtn');
            btn.disabled = true;
            btn.textContent = 'Sending\u2026';
            var payload = {
                name: document.getElementById('contactName').value.trim(),
                email: document.getElementById('contactEmail').value.trim(),
                company: document.getElementById('contactCompany').value.trim(),
                teamSize: document.getElementById('contactTeamSize').value,
                interest: document.getElementById('contactInterest').value
            };
            var FORM_URL = 'https://script.google.com/macros/s/AKfycbzYbbgDcMm_9NbNKyKek7BTQT7rzsE4OaaVXNo926hGkxAFD5jOt0IXPXFJVWE7GDGe/exec';
            fetch(FORM_URL, { method: 'POST', mode: 'no-cors', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) })
            .then(function() {
                document.getElementById('contactFormFields').style.display = 'none';
                var st = document.getElementById('contactFormStatus');
                st.className = 'contact-form-status show';
                st.innerHTML = '<div class="status-icon">&#10003;</div><h4>Request Sent!</h4><p>We\u2019ll get back to you within one business day.</p>';
            }).catch(function() {
                document.getElementById('contactFormFields').style.display = 'none';
                var st = document.getElementById('contactFormStatus');
                st.className = 'contact-form-status show';
                st.innerHTML = '<div class="status-icon">&#9993;</div><h4>Almost there!</h4><p>Please email us directly at <a href="mailto:bolt@sparcle.app" style="color:var(--brand-primary)">bolt@sparcle.app</a></p>';
            });
        });
    }

    // Global open/close — works whether modal was injected here or by the page
    if (typeof window.openContactModal === 'undefined') {
        window.openContactModal = function(interest) {
            var overlay = document.getElementById('contactModalOverlay');
            if (!overlay) return;
            document.getElementById('contactInterest').value = interest || 'General Inquiry';
            document.getElementById('contactModalTitle').textContent = interest || 'Get in Touch';
            document.getElementById('contactFormFields').style.display = '';
            var st = document.getElementById('contactFormStatus');
            st.className = 'contact-form-status';
            var btn = document.getElementById('contactSubmitBtn');
            if (btn) { btn.disabled = false; btn.textContent = 'Send Request'; }
            overlay.classList.add('open');
            setTimeout(function() { document.getElementById('contactName').focus(); }, 100);
        };
        window.closeContactModal = function() {
            var overlay = document.getElementById('contactModalOverlay');
            if (overlay) overlay.classList.remove('open');
            var form = document.getElementById('contactForm');
            if (form) form.reset();
        };
        document.addEventListener('click', function(e) {
            var overlay = document.getElementById('contactModalOverlay');
            if (e.target === overlay) window.closeContactModal();
        });
        document.addEventListener('keydown', function(e) {
            if (e.key === 'Escape') {
                var overlay = document.getElementById('contactModalOverlay');
                if (overlay && overlay.classList.contains('open')) window.closeContactModal();
            }
        });

        // Intercept any remaining mailto:bolt@sparcle.app links site-wide
        document.addEventListener('click', function(e) {
            var link = e.target.closest('a[href^="mailto:bolt@sparcle"]');
            if (link) {
                e.preventDefault();
                var subj = '';
                try { subj = decodeURIComponent(new URL(link.href).searchParams.get('subject') || ''); } catch(_){}
                window.openContactModal(subj || 'General Inquiry');
            }
            // Also handle #contact: links from offerings.ts
            var contactLink = e.target.closest('a[href^="#contact:"]');
            if (contactLink) {
                e.preventDefault();
                var interest = contactLink.getAttribute('href').replace('#contact:', '');
                window.openContactModal(interest);
            }
        });
    }

    // Auto-open contact modal if URL hash is #contact or #contact:Interest
    // Runs unconditionally — works on all pages regardless of who defined openContactModal
    (function() {
        var hash = window.location.hash;
        if (hash && hash.indexOf('#contact') === 0) {
            var interest = (hash.charAt(8) === ':')
                ? decodeURIComponent(hash.slice(9))
                : 'Get in Touch';
            function tryOpen() {
                if (typeof window.openContactModal === 'function' && document.getElementById('contactModalOverlay')) {
                    window.openContactModal(interest);
                } else {
                    setTimeout(tryOpen, 100);
                }
            }
            setTimeout(tryOpen, 50);
        }
    }());

}());
