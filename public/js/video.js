/**
 * Video Modal Controller
 * Handles click-to-zoom, play/pause, and fullscreen video playback
 */
document.addEventListener('DOMContentLoaded', () => {
    const videoWrapper = document.getElementById('videoWrapper');
    const heroVideo = document.getElementById('heroVideo');
    const playOverlay = document.getElementById('playOverlay');
    const videoModal = document.getElementById('videoModal');
    const modalBackdrop = document.getElementById('modalBackdrop');
    const modalVideo = document.getElementById('modalVideo');
    const modalClose = document.getElementById('modalClose');

    if (!videoWrapper || !videoModal) return;

    // Click on video wrapper opens modal
    videoWrapper.addEventListener('click', (e) => {
        e.preventDefault();
        openModal();
    });

    // Close modal
    modalClose?.addEventListener('click', closeModal);
    modalBackdrop?.addEventListener('click', closeModal);

    // Escape key closes modal
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && videoModal.classList.contains('active')) {
            closeModal();
        }
    });

    function openModal() {
        videoModal.classList.add('active');
        document.body.style.overflow = 'hidden';

        // Start from beginning with audio
        if (modalVideo) {
            modalVideo.currentTime = 0;
            modalVideo.muted = false;
            modalVideo.play().catch(console.log);
        }
    }

    function closeModal() {
        videoModal.classList.remove('active');
        document.body.style.overflow = '';

        if (modalVideo) {
            modalVideo.pause();
        }
    }

    // Preview play on hover (muted)
    let hoverTimeout;
    videoWrapper.addEventListener('mouseenter', () => {
        hoverTimeout = setTimeout(() => {
            if (heroVideo && !videoModal.classList.contains('active')) {
                heroVideo.muted = true;
                heroVideo.currentTime = 0;
                heroVideo.play().catch(console.log);
                playOverlay?.classList.add('hidden');
            }
        }, 300);
    });

    videoWrapper.addEventListener('mouseleave', () => {
        clearTimeout(hoverTimeout);
        if (heroVideo) {
            heroVideo.pause();
            heroVideo.currentTime = 0;
            playOverlay?.classList.remove('hidden');
        }
    });
});
