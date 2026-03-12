/**
 * Scroll Animations
 * Intersection Observer for animate-on-scroll elements
 */
document.addEventListener('DOMContentLoaded', () => {
    // Intersection Observer for scroll animations
    const observerOptions = {
        root: null,
        rootMargin: '0px',
        threshold: 0.1
    };

    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('visible');
                // Stagger animation for siblings
                const parent = entry.target.parentElement;
                const siblings = parent?.querySelectorAll('.animate-on-scroll');
                siblings?.forEach((sibling, index) => {
                    sibling.style.transitionDelay = `${index * 0.1}s`;
                });
            }
        });
    }, observerOptions);

    // Observe all animate-on-scroll elements
    document.querySelectorAll('.animate-on-scroll').forEach(el => {
        observer.observe(el);
    });

    // Smooth scroll for anchor links
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            const href = this.getAttribute('href');
            if (href && href !== '#') {
                e.preventDefault();
                const target = document.querySelector(href);
                if (target) {
                    const navHeight = document.querySelector('.navbar')?.offsetHeight || 80;
                    const targetPosition = target.getBoundingClientRect().top + window.pageYOffset - navHeight - 20;
                    window.scrollTo({
                        top: targetPosition,
                        behavior: 'smooth'
                    });
                }
            }
        });
    });

    // Parallax effect for hero orbs on mouse move
    const heroOrbs = document.querySelectorAll('.hero-orb');
    if (heroOrbs.length > 0) {
        document.addEventListener('mousemove', (e) => {
            const x = (e.clientX / window.innerWidth - 0.5) * 20;
            const y = (e.clientY / window.innerHeight - 0.5) * 20;

            heroOrbs.forEach((orb, index) => {
                const factor = (index + 1) * 0.5;
                orb.style.transform = `translate(${x * factor}px, ${y * factor}px)`;
            });
        });
    }

    // ── Animated number counters ──────────────────────────────────────────
    const counterElements = document.querySelectorAll('.stat-number, .proof-metric');

    const animateCounter = (el) => {
        const raw = el.textContent.trim();
        // Extract numeric part and suffix (e.g. "473" → 473, "$450B" → 450)
        const match = raw.match(/^([^0-9]*)([0-9]+)(.*)$/);
        if (!match) return;

        const prefix = match[1];   // "$" or ""
        const target = parseInt(match[2], 10);
        const suffix = match[3];   // "%" or "s" or "B" or "+"

        const duration = 1500;
        const start = performance.now();

        const step = (now) => {
            const elapsed = now - start;
            const progress = Math.min(elapsed / duration, 1);
            // Ease out cubic
            const eased = 1 - Math.pow(1 - progress, 3);
            const current = Math.round(target * eased);
            el.textContent = prefix + current + suffix;
            if (progress < 1) requestAnimationFrame(step);
        };

        el.textContent = prefix + '0' + suffix;
        requestAnimationFrame(step);
    };

    const counterObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                animateCounter(entry.target);
                counterObserver.unobserve(entry.target);
            }
        });
    }, { threshold: 0.3 });

    counterElements.forEach(el => counterObserver.observe(el));

    // ── 3D Tilt Effect on Cards ──────────────────────────────────────────
    const tiltCards = document.querySelectorAll('.stat-card, .proof-card');

    tiltCards.forEach(card => {
        card.addEventListener('mousemove', (e) => {
            const rect = card.getBoundingClientRect();
            const x = e.clientX - rect.left;
            const y = e.clientY - rect.top;
            const centerX = rect.width / 2;
            const centerY = rect.height / 2;
            const rotateX = ((y - centerY) / centerY) * -6; // max 6deg
            const rotateY = ((x - centerX) / centerX) * 6;

            card.style.transform = `translateY(-6px) perspective(800px) rotateX(${rotateX}deg) rotateY(${rotateY}deg)`;
        });

        card.addEventListener('mouseleave', () => {
            card.style.transform = '';
        });
    });

    // ── Touch-Friendly Video Play Overlay ────────────────────────────────
    const boltOverlay = document.getElementById('boltPlayOverlay');
    const boltVideo = document.getElementById('boltVideo');

    if (boltOverlay && boltVideo) {
        boltOverlay.addEventListener('click', () => {
            boltVideo.play();
            boltOverlay.classList.add('hidden');
        });

        boltVideo.addEventListener('pause', () => {
            boltOverlay.classList.remove('hidden');
        });

        boltVideo.addEventListener('ended', () => {
            boltOverlay.classList.remove('hidden');
        });
    }
});
