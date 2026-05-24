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
 *     (function(){var t=localStorage.getItem('theme')||'light';
 *     document.documentElement.setAttribute('data-theme',t);})();
 *   </script>
 */

(function () {
    'use strict';

    // Idempotency guard: avoid duplicate global listeners if script is loaded twice.
    if (window.__sparcleSharedNavInitialized) return;
    window.__sparcleSharedNavInitialized = true;

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
        // Bolt: /products.html or any /products subpath WITHOUT /aeira (so the
        // dual-product page lights up the Bolt tab unless the URL is the
        // Aeira variant).
        if (page === 'bolt'
            && (path === '/products.html' || path === '/products.html/'
                || (path.indexOf('/products') !== -1 && path.indexOf('aeira') === -1))) {
            return ' nav-active';
        }
        if (page === 'aeira' && path.indexOf('/aeira') !== -1) return ' nav-active';
        if (page === 'resources' && (path.indexOf('architecture') !== -1 || path.indexOf('security') !== -1 || path.indexOf('integrations') !== -1 || path.indexOf('research') !== -1 || path.indexOf('terms') !== -1 || path.indexOf('privacy') !== -1)) return ' nav-active';
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
        '    <li><a href="/products.html" class="nav-link' + activeClass('bolt') + '">Bolt</a></li>',
        '    <li><a href="/products/aeira.html" class="nav-link' + activeClass('aeira') + '">Aeira</a></li>',
        '    <li><a href="/solution" class="nav-link' + activeClass('solution') + '">Solutions</a></li>',
        '    <li><a href="/pricing#bolt" class="nav-link' + activeClass('pricing') + '">Pricing</a></li>',
        '    <li class="nav-item-has-submenu">',
        '      <button type="button" class="nav-link submenu-toggle-btn' + activeClass('resources') + '" aria-expanded="false" aria-haspopup="true">',
        '        Resources',
        '        <svg class="submenu-caret" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">',
        '          <polyline points="6 9 12 15 18 9"/>',
        '        </svg>',
        '      </button>',
        '      <ul class="nav-submenu">',
        '        <li><a href="/docs" class="nav-link">Documentation</a></li>',
        '        <li><a href="/architecture" class="nav-link">Architecture</a></li>',
        '        <li><a href="/security" class="nav-link">Security &amp; Compliance</a></li>',
        '        <li><a href="/integrations" class="nav-link">Integrations</a></li>',
        '        <li><a href="/why-sparcle" class="nav-link">Why Sparcle</a></li>',
        '        <li><a href="/research.html" class="nav-link">Research &amp; Whitepaper</a></li>',
        '        <li><a href="/crisis" class="nav-link">The Crisis (background)</a></li>',
        '        <li><a href="/terms#ip" class="nav-link">Patents &amp; IP</a></li>',
        '        <li><a href="/status" class="nav-link">Status</a></li>',
        '      </ul>',
        '    </li>',
        '  </ul>',
        '  <div class="nav-controls">',
        '    <div class="theme-switch" id="themeSwitch" role="group" aria-label="Color theme">',
        '      <button type="button" class="theme-switch__opt" data-theme-set="auto" aria-pressed="false" aria-label="Use system theme" title="System">',
        '        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">',
        '          <circle cx="12" cy="12" r="9"/>',
        '          <path d="M12 3A9 9 0 0 0 12 21Z" fill="currentColor" stroke="none"/>',
        '        </svg>',
        '      </button>',
        '      <button type="button" class="theme-switch__opt" data-theme-set="light" aria-pressed="false" aria-label="Use light theme" title="Light">',
        '        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">',
        '          <circle cx="12" cy="12" r="4.5"/>',
        '          <line x1="12" y1="2" x2="12" y2="4"/>',
        '          <line x1="12" y1="20" x2="12" y2="22"/>',
        '          <line x1="4.93" y1="4.93" x2="6.34" y2="6.34"/>',
        '          <line x1="17.66" y1="17.66" x2="19.07" y2="19.07"/>',
        '          <line x1="2" y1="12" x2="4" y2="12"/>',
        '          <line x1="20" y1="12" x2="22" y2="12"/>',
        '          <line x1="4.93" y1="19.07" x2="6.34" y2="17.66"/>',
        '          <line x1="17.66" y1="6.34" x2="19.07" y2="4.93"/>',
        '        </svg>',
        '      </button>',
        '      <button type="button" class="theme-switch__opt" data-theme-set="dark" aria-pressed="false" aria-label="Use dark theme" title="Dark">',
        '        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">',
        '          <path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/>',
        '        </svg>',
        '      </button>',
        '    </div>',
        '    <a href="#" onclick="openContactModal(\'Architecture Review\'); return false;" class="btn btn-primary btn-sm">Schedule Review</a>',
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
        '          <li><a href="/products/aeira.html" style="display:inline-flex;align-items:center;gap:0.4rem;"><img src="/images/aeira-logo.svg" alt="" width="16" height="16" style="border-radius:3px;">Aeira</a></li>',
        '          <li><a href="/download" style="display:inline-flex;align-items:center;gap:0.4rem;">' +
        '            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
        '              <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>' +
        '              <polyline points="7 10 12 15 17 10"/>' +
        '              <line x1="12" y1="15" x2="12" y2="3"/>' +
        '            </svg>Trial or Free</a></li>',
        '        </ul>',
        '      </div>',
        '      <div class="footer-col">',
        '        <h5>Resources</h5>',
        '        <ul>',
        '          <li><a href="/docs">Documentation</a></li>',
        '          <li><a href="/architecture">Architecture</a></li>',
        '          <li><a href="/security">Security &amp; Compliance</a></li>',
        '          <li><a href="/integrations">Integrations</a></li>',
        '          <li><a href="/research.html">Research &amp; Whitepaper</a></li>',
        '          <li><a href="/media/Bolt_Strategic_Vision.pdf" target="_blank">Strategic Vision</a></li>',
        '          <li><a href="https://sparcle.app/legacy/whitepaper-print.html" target="_blank">Full Whitepaper</a></li>',
        '          <li><a href="/status">Status</a></li>',
        '        </ul>',
        '      </div>',
        '      <div class="footer-col">',
        '        <h5>Company</h5>',
        '        <ul>',
        '          <li><a href="#" onclick="openContactModal(); return false;">Contact</a></li>',
        '          <li><a href="/careers">Careers</a></li>',
        '          <li><a href="/privacy">Privacy Policy</a></li>',
        '          <li><a href="/terms">Terms of Service</a></li>',
        '        </ul>',
        '      </div>',
        '    </div>',
        '    <div class="footer-bottom">',
        '      <span>&copy; 2026 Sparcle, LLC. All rights reserved.</span>',
        '      <span class="footer-legal"><a href="/terms#ip" style="color:inherit;text-decoration:none;">Patents pending</a></span>',
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
       THEME INIT & SEGMENTED SWITCH
       ------------------------------------------------------------------
       3-state segmented control: [ Auto | Light | Dark ]
       - 'auto'  : follow prefers-color-scheme; no localStorage entry.
       - 'light' : explicit; saved to localStorage.
       - 'dark'  : explicit; saved to localStorage.
       The FOUC-prevention script in BaseLayout has already resolved the
       initial theme; this block manages the switch's pressed state +
       direct mode selection.
       ------------------------------------------------------------------ */
    (function initTheme() {
        var root = document.documentElement;
        var mql = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)');

        function systemTheme() { return mql && mql.matches ? 'dark' : 'light'; }

        function currentMode() {
            var saved = localStorage.getItem('theme');
            return (saved === 'dark' || saved === 'light') ? saved : 'auto';
        }

        function applyMode(mode) {
            root.setAttribute('data-theme', mode === 'auto' ? systemTheme() : mode);
        }

        function setMode(mode) {
            if (mode === 'auto') {
                localStorage.removeItem('theme');
            } else {
                localStorage.setItem('theme', mode);
            }
            applyMode(mode);
            updateSwitchUI(mode);
        }

        function updateSwitchUI(mode) {
            var opts = document.querySelectorAll('.theme-switch__opt');
            opts.forEach(function (b) {
                var on = b.getAttribute('data-theme-set') === mode;
                b.setAttribute('aria-pressed', on ? 'true' : 'false');
            });
        }

        applyMode(currentMode());
        updateSwitchUI(currentMode());

        document.querySelectorAll('.theme-switch__opt').forEach(function (btn) {
            btn.addEventListener('click', function () {
                var mode = btn.getAttribute('data-theme-set') || 'auto';
                setMode(mode);
            });
        });

        // Live system-pref response (only matters when in 'auto').
        if (mql && mql.addEventListener) {
            mql.addEventListener('change', function () {
                if (currentMode() === 'auto') applyMode('auto');
            });
        }
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

    /* ------------------------------------------------------------------
       SUBMENU TOGGLE — Resources dropdown
       ------------------------------------------------------------------
       Click-driven on every device. Previously the submenu was
       hover-only on desktop and completely unreachable on mobile.
       Now: clicking the chevron toggles .submenu-open on the parent
       <li> + flips aria-expanded on the button. Outside-click / Esc
       closes any open submenu. The Resources <a> stays clickable
       as a direct link to /why-sparcle.
       ------------------------------------------------------------------ */
    (function initSubmenuToggle() {
        var toggles = document.querySelectorAll('.submenu-toggle, .submenu-toggle-btn');
        if (!toggles.length) return;

        function closeAll(except) {
            document.querySelectorAll('.nav-item-has-submenu.submenu-open').forEach(function (li) {
                if (li === except) return;
                li.classList.remove('submenu-open');
                var btn = li.querySelector('.submenu-toggle');
                if (btn) btn.setAttribute('aria-expanded', 'false');
            });
        }

        toggles.forEach(function (btn) {
            btn.addEventListener('click', function (e) {
                e.stopPropagation();
                e.preventDefault();
                var li = btn.closest('.nav-item-has-submenu');
                if (!li) return;
                var open = li.classList.toggle('submenu-open');
                btn.setAttribute('aria-expanded', String(open));
                if (open) closeAll(li);
            });
        });

        document.addEventListener('click', function (e) {
            if (e.target.closest('.nav-item-has-submenu')) return;
            closeAll(null);
        });

        document.addEventListener('keydown', function (e) {
            if (e.key === 'Escape') closeAll(null);
        });
    }());

    /* Scrollspy removed — all nav links now go to dedicated pages */

    /* ------------------------------------------------------------------
       SHARED CONTACT MODAL
       Only inject if the page doesn't already have one (pricing/index have theirs)
       ------------------------------------------------------------------ */
    var sharedTurnstileWidgetId = null;

    function sharedRenderTurnstile() {
        var siteKey = (window.SPARCLE_CONFIG && window.SPARCLE_CONFIG.turnstileSiteKey) || '';
        var wrap = document.getElementById('contactTurnstileWrap');
        if (!siteKey || !window.turnstile || !wrap) return;
        if (sharedTurnstileWidgetId !== null) {
            try { window.turnstile.reset(sharedTurnstileWidgetId); } catch (e) {}
            return;
        }
        sharedTurnstileWidgetId = window.turnstile.render(wrap, {
            sitekey: siteKey,
            theme: 'auto'
        });
    }

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
            '        <div class="contact-form-group" id="contactTurnstileWrap"></div>',
            '        <p class="contact-privacy-note">Submissions are emailed to Sparcle. We don\u2019t share or sell.</p>',
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
            var st  = document.getElementById('contactFormStatus');

            var token = '';
            if (window.turnstile && sharedTurnstileWidgetId !== null) {
                try { token = window.turnstile.getResponse(sharedTurnstileWidgetId) || ''; } catch (err) {}
            }
            if (!token) {
                st.className = 'contact-form-status show error';
                st.innerHTML = '<p>Please complete the verification challenge.</p>';
                return;
            }

            btn.disabled = true;
            btn.textContent = 'Sending\u2026';
            var payload = {
                name: document.getElementById('contactName').value.trim(),
                email: document.getElementById('contactEmail').value.trim(),
                company: document.getElementById('contactCompany').value.trim(),
                teamSize: document.getElementById('contactTeamSize').value,
                interest: document.getElementById('contactInterest').value,
                turnstileToken: token
            };
            fetch('/api/contact', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            })
            .then(function(r) {
                return r.json().then(function(data) { return { ok: r.ok, data: data }; });
            })
            .then(function(result) {
                if (!result.ok || !result.data || !result.data.ok) throw new Error('send_failed');
                document.getElementById('contactFormFields').style.display = 'none';
                st.className = 'contact-form-status show';
                st.innerHTML = '<div class="status-icon">&#10003;</div><h4>Request Sent!</h4><p>We\u2019ll get back to you within one business day.</p>';
            }).catch(function() {
                btn.disabled = false;
                btn.textContent = 'Send Request';
                if (window.turnstile && sharedTurnstileWidgetId !== null) {
                    try { window.turnstile.reset(sharedTurnstileWidgetId); } catch (e) {}
                }
                document.getElementById('contactFormFields').style.display = 'none';
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
            var attempts = 0;
            var iv = setInterval(function() {
                if (window.turnstile || attempts++ > 40) {
                    clearInterval(iv);
                    sharedRenderTurnstile();
                }
            }, 100);
        };
        window.closeContactModal = function() {
            var overlay = document.getElementById('contactModalOverlay');
            if (overlay) overlay.classList.remove('open');
            var form = document.getElementById('contactForm');
            if (form) form.reset();
            if (window.turnstile && sharedTurnstileWidgetId !== null) {
                try { window.turnstile.reset(sharedTurnstileWidgetId); } catch (e) {}
            }
        };
        document.addEventListener('click', function(e) {
            var overlay = document.getElementById('contactModalOverlay');
            if (e.target === overlay) window.closeContactModal();
        });
        document.addEventListener('keydown', function(e) {
            var overlay = document.getElementById('contactModalOverlay');
            if (!overlay || !overlay.classList.contains('open')) return;
            if (e.key === 'Escape') { window.closeContactModal(); return; }
            // Focus trap
            if (e.key === 'Tab') {
                var focusables = overlay.querySelectorAll('input,select,textarea,button,[tabindex]:not([tabindex="-1"])');
                if (!focusables.length) return;
                var first = focusables[0], last = focusables[focusables.length - 1];
                if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
                else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
            }
        });

        // Intercept any remaining mailto:bolt@sparcle.app links site-wide
        // (skip links with data-no-modal, e.g. careers apply links)
        document.addEventListener('click', function(e) {
            var link = e.target.closest('a[href^="mailto:bolt@sparcle"]');
            if (link && !link.hasAttribute('data-no-modal')) {
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
