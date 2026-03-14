// Video Gallery with Popout & Controls

document.addEventListener('DOMContentLoaded', function () {
    const videoContainers = document.querySelectorAll('.video-container');
    
    // Global Escape key handler
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape') {
            closeAllExpandedVideos();
        }
    });

    // Click outside handler (Backdrop click)
    document.addEventListener('click', function(e) {
        if (document.body.classList.contains('has-expanded-video')) {
            // If clicking outside any expanded video container
            if (!e.target.closest('.video-container.expanded')) {
                closeAllExpandedVideos();
            }
        }
    });

    videoContainers.forEach(container => {
        const video = container.querySelector('video');
        const playPauseBtn = container.querySelector('.play-pause-btn');
        const maximizeBtn = container.querySelector('.maximize-btn');

        // Container Click -> Expand & Play
        container.addEventListener('click', function (e) {
            // If clicking controls, don't trigger expand logic (let controls handle it)
            if (e.target.closest('.video-controls')) return;

            // If in native fullscreen, let the browser handle clicks (prevents double toggle)
            if (document.fullscreenElement || document.webkitFullscreenElement) return;

            if (!container.classList.contains('expanded')) {
                expandVideo(container, video);
            } else {
                // If already expanded and clicking video, toggle play
                togglePlay(container, video);
            }
        });

        // Play/Pause Button Click
        playPauseBtn.addEventListener('click', function (e) {
            e.stopPropagation();
            if (!container.classList.contains('expanded')) {
                expandVideo(container, video);
            } else {
                togglePlay(container, video);
            }
        });

        // Maximize Button Click -> Native Fullscreen
        maximizeBtn.addEventListener('click', function (e) {
            e.stopPropagation();
            toggleNativeFullscreen(video);
        });

        // Video Ended
        video.addEventListener('ended', function () {
            container.classList.remove('playing');
        });
    });

    function expandVideo(container, video) {
        // Close others first
        closeAllExpandedVideos();

        // Expand this one
        container.classList.add('expanded');
        document.body.classList.add('has-expanded-video');
        
        // Play automatically
        playVideo(container, video);
    }

    function closeAllExpandedVideos() {
        videoContainers.forEach(container => {
            if (container.classList.contains('expanded')) {
                container.classList.remove('expanded');
                const video = container.querySelector('video');
                pauseVideo(container, video);
            }
        });
        document.body.classList.remove('has-expanded-video');
    }

    function togglePlay(container, video) {
        if (video.paused) {
            playVideo(container, video);
        } else {
            pauseVideo(container, video);
        }
    }

    function playVideo(container, video) {
        container.classList.add('playing');
        video.play().catch(err => console.log('Play failed:', err));
    }

    function pauseVideo(container, video) {
        container.classList.remove('playing');
        video.pause();
    }

    function toggleNativeFullscreen(video) {
        if (!document.fullscreenElement) {
            if (video.requestFullscreen) video.requestFullscreen();
            else if (video.webkitRequestFullscreen) video.webkitRequestFullscreen();
        } else {
            if (document.exitFullscreen) document.exitFullscreen();
            else if (document.webkitExitFullscreen) document.webkitExitFullscreen();
        }
    }
});
