// ============================================
// Sparcle.LLC - Main JavaScript
// Interactive functionality and animations
// ============================================

document.addEventListener('DOMContentLoaded', function () {
    // Initialize all features
    // Theme is handled by theme.js
    // initTheme(); - REMOVED

    initNavigation();
    initScrollEffects();
    initNetworkAnimation();
    initFloatingCTA();
});

// ============================================
// Navigation
// ============================================

function initNavigation() {
    const navbar = document.getElementById('navbar');
    if (!navbar) return;

    const navToggle = document.getElementById('navToggle');
    const navMenu = document.getElementById('navMenu');

    // Scroll effect (shared-nav.js also sets this but passive listeners are fine to stack)
    window.addEventListener('scroll', () => {
        const currentScroll = window.pageYOffset;
        navbar.classList.toggle('scrolled', currentScroll > 10);
    }, { passive: true });

    // Mobile menu toggle — skip if shared-nav.js already wired this up
    if (navToggle && navMenu && !navToggle.dataset.navInit) {
        navToggle.dataset.navInit = 'true';

        navToggle.addEventListener('click', () => {
            const open = navMenu.classList.toggle('open');
            navToggle.classList.toggle('open', open);
            navToggle.setAttribute('aria-expanded', String(open));
        });

        // Close menu when clicking outside
        document.addEventListener('click', (e) => {
            if (!navToggle.contains(e.target) && !navMenu.contains(e.target)) {
                navMenu.classList.remove('open');
                navToggle.classList.remove('open');
                navToggle.setAttribute('aria-expanded', 'false');
            }
        });

        // Close menu when clicking a link
        const navLinks = navMenu.querySelectorAll('a');
        navLinks.forEach(link => {
            link.addEventListener('click', () => {
                navMenu.classList.remove('open');
                navToggle.classList.remove('open');
                navToggle.setAttribute('aria-expanded', 'false');
            });
        });
    }
}

// ============================================
// Scroll Effects
// ============================================

function initScrollEffects() {
    // Fade in elements on scroll
    const observerOptions = {
        threshold: 0.1,
        rootMargin: '0px 0px -50px 0px'
    };

    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('animate-fade-in');
                observer.unobserve(entry.target);
            }
        });
    }, observerOptions);

    // Observe elements
    const animateElements = document.querySelectorAll('.feature-card, .product-card');
    animateElements.forEach(el => observer.observe(el));
}

// ============================================
// Network Animation (Hero Section)
// ============================================

function initNetworkAnimation() {
    const container = document.getElementById('toolNodes');
    if (!container) return;

    // Tool logos to display
    const tools = [
        { name: 'Slack', color: '#E01E5A' },
        { name: 'Jira', color: '#0052CC' },
        { name: 'GitHub', color: '#24292E' },
        { name: 'Salesforce', color: '#00A1E0' },
        { name: 'Notion', color: '#000000' },
        { name: 'Gmail', color: '#EA4335' },
        { name: 'Calendar', color: '#4285F4' },
        { name: 'Drive', color: '#0F9D58' },
        { name: 'Teams', color: '#6264A7' },
        { name: 'Zoom', color: '#2D8CFF' },
        { name: 'Asana', color: '#F06A6A' },
        { name: 'Figma', color: '#F24E1E' }
    ];

    // Create tool nodes in a circle
    const radius = 200; // Distance from center
    const centerX = 250;
    const centerY = 250;

    tools.forEach((tool, index) => {
        const angle = (index / tools.length) * 2 * Math.PI;
        const x = centerX + radius * Math.cos(angle);
        const y = centerY + radius * Math.sin(angle);

        // Create node
        const node = document.createElement('div');
        node.className = 'tool-node';
        node.style.cssText = `
            position: absolute;
            left: ${x}px;
            top: ${y}px;
            width: 50px;
            height: 50px;
            background-color: ${tool.color};
            border-radius: 12px;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-size: 0.75rem;
            font-weight: 600;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
            transform: translate(-50%, -50%);
            animation: float ${3 + Math.random() * 2}s ease-in-out infinite;
            animation-delay: ${index * 0.1}s;
        `;
        node.textContent = tool.name.slice(0, 2);
        node.title = tool.name;

        // Create connection line
        const line = document.createElementNS('http://www.w3.org/2000/svg', 'line');
        line.setAttribute('x1', centerX);
        line.setAttribute('y1', centerY);
        line.setAttribute('x2', x);
        line.setAttribute('y2', y);
        line.setAttribute('stroke', 'rgba(59, 130, 246, 0.2)');
        line.setAttribute('stroke-width', '2');
        line.style.cssText = `
            animation: pulse-line ${2 + Math.random()}s ease-in-out infinite;
            animation-delay: ${index * 0.1}s;
        `;

        container.appendChild(node);

        // Add SVG for lines if it doesn't exist
        let svg = container.querySelector('svg');
        if (!svg) {
            svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
            svg.style.cssText = `
                position: absolute;
                top: 0;
                left: 0;
                width: 100%;
                height: 100%;
                pointer-events: none;
            `;
            container.insertBefore(svg, container.firstChild);
        }
        svg.appendChild(line);
    });

    // Add CSS animations
    const style = document.createElement('style');
    style.textContent = `
        @keyframes float {
            0%, 100% { transform: translate(-50%, -50%) translateY(0px); }
            50% { transform: translate(-50%, -50%) translateY(-10px); }
        }
        @keyframes pulse-line {
            0%, 100% { opacity: 0.2; }
            50% { opacity: 0.6; }
        }
    `;
    document.head.appendChild(style);
}

// ============================================
// Floating CTA Button
// ============================================

function initFloatingCTA() {
    const floatingCTA = document.getElementById('floatingCta');
    if (!floatingCTA) return;

    let scrollTimeout;
    window.addEventListener('scroll', () => {
        const scrollPosition = window.pageYOffset;

        // Show after scrolling past hero (roughly 100vh)
        if (scrollPosition > window.innerHeight * 0.8) {
            floatingCTA.classList.add('visible');
        } else {
            floatingCTA.classList.remove('visible');
        }

        // Hide while scrolling, show when stopped
        floatingCTA.style.opacity = '0.5';
        clearTimeout(scrollTimeout);
        scrollTimeout = setTimeout(() => {
            floatingCTA.style.opacity = '1';
        }, 150);
    });
}

// ============================================
// Smooth Scroll (Polyfill for older browsers)
// ============================================

document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        const href = this.getAttribute('href');
        if (href === '#') return;

        e.preventDefault();
        const target = document.querySelector(href);
        if (target) {
            target.scrollIntoView({
                behavior: 'smooth',
                block: 'start'
            });
        }
    });
});

// ============================================
// ROI Calculator (if on that page)
// ============================================

if (document.getElementById('roiCalculator')) {
    const employeeInput = document.getElementById('employees');
    const avgSalaryInput = document.getElementById('avgSalary');
    const resultDiv = document.getElementById('roiResult');

    function calculateROI() {
        const employees = parseInt(employeeInput.value) || 0;
        const avgSalary = parseInt(avgSalaryInput.value) || 60000;

        // Assumptions
        const minutesSavedPerDay = 12; // Conservative estimate
        const workDaysPerYear = 250;
        const hoursPerWorkDay = 8;
        const hourlyRate = avgSalary / (workDaysPerYear * hoursPerWorkDay);

        // Calculate savings
        const hoursSavedPerYear = (minutesSavedPerDay / 60) * workDaysPerYear * employees;
        const annualSavings = hoursSavedPerYear * hourlyRate;

        // Bolt cost estimate (rough)
        const annualCost = employees * 300; // $300 per user per year (example)
        const netSavings = annualSavings - annualCost;
        const roi = ((netSavings / annualCost) * 100).toFixed(0);

        // Display results
        resultDiv.innerHTML = `
            <div class="roi-results">
                <h3>Your Estimated ROI</h3>
                <div class="roi-stat-grid">
                    <div class="roi-stat">
                        <div class="roi-value">$${annualSavings.toLocaleString()}</div>
                        <div class="roi-label">Annual Time Savings</div>
                    </div>
                    <div class="roi-stat">
                        <div class="roi-value">$${annualCost.toLocaleString()}</div>
                        <div class="roi-label">Estimated Annual Cost</div>
                    </div>
                    <div class="roi-stat highlight">
                        <div class="roi-value">$${netSavings.toLocaleString()}</div>
                        <div class="roi-label">Net Annual Savings</div>
                    </div>
                    <div class="roi-stat highlight">
                        <div class="roi-value">${roi}%</div>
                        <div class="roi-label">Return on Investment</div>
                    </div>
                </div>
                <p class="roi-note">
                    Based on ${minutesSavedPerDay} minutes saved per employee per day. 
                    <a href="/demo.html">Schedule a demo</a> to get a customized ROI analysis.
                </p>
            </div>
        `;
    }

    employeeInput?.addEventListener('input', calculateROI);
    avgSalaryInput?.addEventListener('input', calculateROI);

    // Calculate on load
    if (employeeInput && avgSalaryInput) {
        calculateROI();
    }
}

// ============================================
// Form Validation (Contact/Demo forms)
// ============================================

const forms = document.querySelectorAll('form.contact-form, form.demo-form');
forms.forEach(form => {
    form.addEventListener('submit', async function (e) {
        e.preventDefault();

        const submitBtn = form.querySelector('button[type="submit"]');
        const originalText = submitBtn.textContent;

        // Simple validation
        const email = form.querySelector('input[type="email"]');
        if (email && !isValidEmail(email.value)) {
            showFormMessage(form, 'Please enter a valid email address', 'error');
            return;
        }

        // Show loading state
        submitBtn.textContent = 'Sending...';
        submitBtn.disabled = true;

        // Simulate form submission (replace with actual endpoint)
        setTimeout(() => {
            showFormMessage(form, 'Thank you! We\'ll be in touch soon.', 'success');
            form.reset();
            submitBtn.textContent = originalText;
            submitBtn.disabled = false;
        }, 1500);

        // In production, replace with actual API call:
        // const formData = new FormData(form);
        // const response = await fetch('/api/contact', {
        //     method: 'POST',
        //     body: formData
        // });
    });
});

function isValidEmail(email) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function showFormMessage(form, message, type) {
    const existingMessage = form.querySelector('.form-message');
    if (existingMessage) {
        existingMessage.remove();
    }

    const messageDiv = document.createElement('div');
    messageDiv.className = `form-message ${type}`;
    messageDiv.textContent = message;
    form.insertBefore(messageDiv, form.firstChild);

    setTimeout(() => {
        messageDiv.remove();
    }, 5000);
}

// ============================================
// Analytics (Google Analytics 4 - Placeholder)
// ============================================

// Track page views
function trackPageView() {
    if (typeof gtag !== 'undefined') {
        gtag('event', 'page_view', {
            page_path: window.location.pathname
        });
    }
}

// Track button clicks
document.querySelectorAll('.btn-primary, .btn-secondary').forEach(btn => {
    btn.addEventListener('click', function () {
        const text = this.textContent.trim();
        if (typeof gtag !== 'undefined') {
            gtag('event', 'button_click', {
                button_text: text,
                page_path: window.location.pathname
            });
        }
    });
});

// ============================================
// Performance Monitoring
// ============================================


