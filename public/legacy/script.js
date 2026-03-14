// Typing animation with overflow detection and ellipsis
const typingText = document.getElementById('typingText');
const placeholders = [
    "Sparcle — AI-first productivity for macOS",
    "Type app name to launch",
    "Press ↓ for quick access: @app, @file, @plugin",
    "Ask anything: weather, organize docs, play music, !command",
    "Connects to any LLM: private/local or popular providers",
    "Privacy First: data sanitized before leaving your device"
];

let currentPlaceholderIndex = 0;
let charIndex = 0;
let typingSpeed = 80;
let pauseBeforeNext = 1200;
const ellipsis = "…";

function fits(candidate) {
    if (!typingText) return true;
    typingText.textContent = candidate;
    // Force reflow for accurate measurement
    // eslint-disable-next-line no-unused-expressions
    typingText.offsetWidth;
    return typingText.scrollWidth <= typingText.clientWidth;
}

function typeText() {
    const currentText = placeholders[currentPlaceholderIndex];

    const next = currentText.substring(0, charIndex + 1);

    // If adding next char would overflow, back off to fit and finalize with ellipsis
    if (!fits(next)) {
        let j = charIndex;
        while (j > 0 && !fits(currentText.substring(0, j) + ellipsis)) j--;
        typingText.textContent = currentText.substring(0, j) + ellipsis;
        // Pause, then move to next placeholder
        setTimeout(() => {
            currentPlaceholderIndex = (currentPlaceholderIndex + 1) % placeholders.length;
            charIndex = 0;
            typingText.textContent = "";
            setTimeout(typeText, 400);
        }, pauseBeforeNext);
        return;
    }

    typingText.textContent = next;
    charIndex++;

    if (charIndex >= currentText.length) {
        // Finished typing; if still fitting, leave as-is and pause before next
        setTimeout(() => {
            currentPlaceholderIndex = (currentPlaceholderIndex + 1) % placeholders.length;
            charIndex = 0;
            typingText.textContent = "";
            setTimeout(typeText, 400);
        }, pauseBeforeNext);
        return;
    }

    setTimeout(typeText, typingSpeed);
}

// Start typing animation when page loads
window.addEventListener('DOMContentLoaded', () => {
    if (!typingText) return;
    typingText.textContent = "";
    setTimeout(typeText, 500);
});

// Waitlist form submission via Formspree

document.getElementById('waitlistForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const form = e.target;
    const emailInput = document.getElementById('emailInput');
    const formMessage = document.getElementById('formMessage');
    const submitButton = form.querySelector('button[type="submit"]');
    const originalButtonText = submitButton.textContent;
    
    // Show loading state
    submitButton.textContent = 'Joining...';
    submitButton.disabled = true;
    formMessage.textContent = '';
    
    try {
        const response = await fetch(form.action, {
            method: 'POST',
            body: new FormData(form),
            headers: {
                'Accept': 'application/json'
            }
        });
        
        if (response.ok) {
            // Success feedback
            formMessage.textContent = '✨ Thanks! We\'ll notify you when Sparcle launches.';
            formMessage.className = 'form-note success';
            emailInput.value = '';
        } else {
            formMessage.textContent = 'Oops! Something went wrong. Please try again.';
            formMessage.className = 'form-note error';
        }
        
    } catch (error) {
        formMessage.textContent = 'Oops! Something went wrong. Please try again.';
        formMessage.className = 'form-note error';
    } finally {
        // Reset button state
        submitButton.textContent = originalButtonText;
        submitButton.disabled = false;
    }
});

// Add smooth scroll behavior
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        e.preventDefault();
        const targetId = this.getAttribute('href');
        const target = document.querySelector(targetId);
        
        if (target) {
            // Update active tab
            document.querySelectorAll('.nav-tab').forEach(tab => {
                tab.classList.remove('active');
            });
            this.classList.add('active');
            
            // Smooth scroll to target
            target.scrollIntoView({
                behavior: 'smooth',
                block: 'start'
            });
        }
    });
});

// Update active tab on scroll
const sections = document.querySelectorAll('section[id]');
const navTabs = document.querySelectorAll('.nav-tab');

window.addEventListener('scroll', () => {
    let current = '';
    
    sections.forEach(section => {
        const sectionTop = section.offsetTop;
        const sectionHeight = section.clientHeight;
        if (pageYOffset >= (sectionTop - 200)) {
            current = section.getAttribute('id');
        }
    });
    
    navTabs.forEach(tab => {
        tab.classList.remove('active');
        if (tab.getAttribute('href') === `#${current}`) {
            tab.classList.add('active');
        }
    });
});

// Simple animation on scroll
const observerOptions = {
    threshold: 0.1,
    rootMargin: '0px 0px -100px 0px'
};

const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            entry.target.style.opacity = '1';
            entry.target.style.transform = 'translateY(0)';
        }
    });
}, observerOptions);

// Observe feature cards
document.querySelectorAll('.feature').forEach((el, index) => {
    el.style.opacity = '0';
    el.style.transform = 'translateY(20px)';
    el.style.transition = `opacity 0.6s ease ${index * 0.1}s, transform 0.6s ease ${index * 0.1}s`;
    observer.observe(el);
});
