/**
 * Universal playback-speed control.
 *
 * Decorates every <video class="js-speed"> on the page with a compact pill of
 * speed buttons (0.5x / 0.75x / 1x default / 1.25x / 1.5x). The pill is inserted
 * as a sibling directly after the video, so it works regardless of the video's
 * surrounding layout and needs no positioned ancestor.
 *
 * Native <video controls> hides playback speed in an overflow menu (and Firefox
 * omits it from the UI entirely), so this exposes it directly and consistently
 * across every browser.
 */
(function () {
  var RATES = [0.5, 0.75, 1, 1.25, 1.5];
  var DEFAULT_RATE = 1;

  function fmt(rate) {
    return (rate === 1 ? '1' : String(rate)) + '×';
  }

  function decorate(video) {
    if (video.getAttribute('data-speed-ready')) return;
    video.setAttribute('data-speed-ready', '1');

    var bar = document.createElement('div');
    bar.className = 'video-speed';
    bar.setAttribute('role', 'group');
    bar.setAttribute('aria-label', 'Playback speed');

    var label = document.createElement('span');
    label.className = 'video-speed__label';
    label.textContent = 'Speed';
    bar.appendChild(label);

    var buttons = [];

    function apply(rate) {
      try { video.playbackRate = rate; } catch (e) {}
      for (var i = 0; i < buttons.length; i++) {
        var on = buttons[i].rate === rate;
        buttons[i].el.classList.toggle('is-active', on);
        buttons[i].el.setAttribute('aria-pressed', on ? 'true' : 'false');
      }
    }

    RATES.forEach(function (rate) {
      var btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'video-speed__btn' + (rate === DEFAULT_RATE ? ' is-active' : '');
      btn.textContent = fmt(rate);
      btn.setAttribute('aria-pressed', rate === DEFAULT_RATE ? 'true' : 'false');
      btn.addEventListener('click', function () { apply(rate); });
      buttons.push({ el: btn, rate: rate });
      bar.appendChild(btn);
    });

    if (video.nextSibling) {
      video.parentNode.insertBefore(bar, video.nextSibling);
    } else {
      video.parentNode.appendChild(bar);
    }

    // Re-assert the chosen rate once metadata loads (some browsers reset
    // playbackRate to 1 when a new source is committed).
    video.addEventListener('loadedmetadata', function () {
      var active = DEFAULT_RATE;
      for (var i = 0; i < buttons.length; i++) {
        if (buttons[i].el.classList.contains('is-active')) active = buttons[i].rate;
      }
      try { video.playbackRate = active; } catch (e) {}
    });

    apply(DEFAULT_RATE);
  }

  function init() {
    var vids = document.querySelectorAll('video.js-speed');
    for (var i = 0; i < vids.length; i++) decorate(vids[i]);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
