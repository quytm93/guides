// ---- Minimal slideshow engine ----
(function () {
  'use strict';

  const deck = document.getElementById('deck');
  const slides = Array.from(deck.querySelectorAll('.slide'));
  const total = slides.length;

  const progressBar = document.getElementById('progressBar');
  const currentEl = document.getElementById('current');
  const totalEl = document.getElementById('total');
  const prevBtn = document.getElementById('prevBtn');
  const nextBtn = document.getElementById('nextBtn');
  const dotsWrap = document.getElementById('dots');
  const helpToggle = document.getElementById('helpToggle');
  const helpPanel = document.getElementById('helpPanel');

  let index = 0;

  // Build navigation dots
  slides.forEach((_, i) => {
    const dot = document.createElement('button');
    dot.className = 'dot';
    dot.setAttribute('aria-label', 'Go to slide ' + (i + 1));
    dot.addEventListener('click', () => go(i));
    dotsWrap.appendChild(dot);
  });
  const dots = Array.from(dotsWrap.children);

  totalEl.textContent = total;

  function render() {
    slides.forEach((slide, i) => {
      slide.classList.remove('is-active', 'is-prev');
      if (i === index) slide.classList.add('is-active');
      else if (i < index) slide.classList.add('is-prev');
    });
    dots.forEach((d, i) => d.classList.toggle('is-active', i === index));

    const pct = total > 1 ? (index / (total - 1)) * 100 : 100;
    progressBar.style.width = pct + '%';
    currentEl.textContent = index + 1;

    prevBtn.disabled = index === 0;
    nextBtn.disabled = index === total - 1;

    // Keep the URL hash in sync so a slide is shareable / refresh-safe
    history.replaceState(null, '', '#' + (index + 1));
  }

  function go(i) {
    index = Math.max(0, Math.min(total - 1, i));
    render();
  }
  const next = () => go(index + 1);
  const prev = () => go(index - 1);

  // Buttons
  nextBtn.addEventListener('click', next);
  prevBtn.addEventListener('click', prev);

  // Keyboard
  document.addEventListener('keydown', (e) => {
    switch (e.key) {
      case 'ArrowRight':
      case ' ':
      case 'PageDown':
        e.preventDefault(); next(); break;
      case 'ArrowLeft':
      case 'PageUp':
        e.preventDefault(); prev(); break;
      case 'Home':
        e.preventDefault(); go(0); break;
      case 'End':
        e.preventDefault(); go(total - 1); break;
      case 'f':
      case 'F':
        toggleFullscreen(); break;
      case '?':
        toggleHelp(); break;
      case 'Escape':
        // When the help panel is open, ESC closes it and stops here so the
        // sidebar handler doesn't also fire on the same keypress.
        if (!helpPanel.hidden) { toggleHelp(); e.stopImmediatePropagation(); }
        break;
    }
  });

  // Touch / swipe
  let touchX = null;
  deck.addEventListener('touchstart', (e) => { touchX = e.changedTouches[0].clientX; }, { passive: true });
  deck.addEventListener('touchend', (e) => {
    if (touchX === null) return;
    const dx = e.changedTouches[0].clientX - touchX;
    if (Math.abs(dx) > 50) (dx < 0 ? next : prev)();
    touchX = null;
  }, { passive: true });

  // Fullscreen
  function toggleFullscreen() {
    if (!document.fullscreenElement) {
      document.documentElement.requestFullscreen?.();
    } else {
      document.exitFullscreen?.();
    }
  }

  // Help panel
  function toggleHelp() { helpPanel.hidden = !helpPanel.hidden; }
  helpToggle.addEventListener('click', toggleHelp);

  // The content sidebar menu (☰) is built by the shared js/sidebar.js,
  // loaded alongside this file on every deck page.

  // Start at hash if present
  const fromHash = parseInt(location.hash.replace('#', ''), 10);
  if (!isNaN(fromHash) && fromHash >= 1 && fromHash <= total) index = fromHash - 1;

  render();
})();
