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
        if (!helpPanel.hidden) toggleHelp();
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

  // ---- Lesson sidebar menu ----
  const LESSONS = [
    { n: '🧰', file: 'bai-2.html', title: 'Chuẩn bị · Cài đặt Xcode 26' },
    { n: 'G1', file: '../glossary-ios.html', title: 'Thuật ngữ iOS & Swift' },
    { n: 'G2', file: '../glossary-swiftui.html', title: 'Thuật ngữ SwiftUI' },
    { n: 'C1', file: 'cs-1.html', title: 'CS-1: AI Photo Editor' },
    { n: 'C2', file: 'cs-19.html', title: 'CS-2: Short-Video Editor' },
    { n: 'C3', file: 'cs-12.html', title: 'CS-3: Music Streaming' },
    { n: 'C4', file: 'cs-5.html', title: 'CS-4: Meditation & Sleep' },
    { n: 'C5', file: 'cs-8.html', title: 'CS-5: E-commerce / Retail' },
    { n: 'C6', file: 'cs-3.html', title: 'CS-6: Personal Finance' },
    { n: 'C7', file: 'cs-6.html', title: 'CS-7: Food Delivery' },
    { n: 'C8', file: 'cs-11.html', title: 'CS-8: Ride-Hailing' },
    { n: 'C9', file: 'cs-4.html', title: 'CS-9: Social Photo Feed' },
    { n: 'C10', file: 'cs-13.html', title: 'CS-10: Dating' },
    { n: 'C11', file: 'cs-14.html', title: 'CS-11: News & Reading' },
    { n: 'C12', file: 'cs-7.html', title: 'CS-12: Casual Mobile Game' },
    { n: 'C13', file: 'cs-2.html', title: 'CS-13: Habit & Fitness Tracker' },
    { n: 'C14', file: 'cs-10.html', title: 'CS-14: Language Learning' },
    { n: 'C15', file: 'cs-9.html', title: 'CS-15: Notes & Productivity' },
    { n: 'C16', file: 'cs-17.html', title: 'CS-16: Kids Education' },
    { n: 'C17', file: 'cs-15.html', title: 'CS-17: AR Furniture & Measure' },
    { n: 'C18', file: 'cs-16.html', title: 'CS-18: Smart-Home Companion' },
    { n: 'C19', file: 'cs-18.html', title: 'CS-19: Enterprise Field App' },
    { n: 'C20', file: 'cs-20.html', title: 'CS-20: AI Chat Assistant' },
    { n: 'P3', file: 'perf-1.html', title: 'Phần 3: Hiệu năng & Sự cố' },
  ];

  (function buildMenu() {
    const here = location.pathname.split('/').pop();

    // The floating home button is replaced by this menu
    const oldHome = document.querySelector('.home-link');
    if (oldHome) oldHome.remove();

    const btn = document.createElement('button');
    btn.className = 'menu-toggle';
    btn.setAttribute('aria-label', 'Danh sách nội dung');
    btn.innerHTML = '☰';

    const overlay = document.createElement('div');
    overlay.className = 'sidebar-overlay';

    const aside = document.createElement('aside');
    aside.className = 'sidebar';
    aside.innerHTML =
      '<div class="sidebar-head">Nội dung khóa học</div>' +
      '<nav class="sidebar-list">' +
      LESSONS.map(function (l) {
        const active = l.file === here ? ' is-active' : '';
        return '<a class="sidebar-item' + active + '" href="' + l.file + '">' +
          '<span class="sidebar-num">' + l.n + '</span>' +
          '<span>' + l.title + '</span></a>';
      }).join('') +
      '</nav>' +
      '<a class="sidebar-home" href="../index.html">⌂ Trang chủ</a>';

    document.body.appendChild(btn);
    document.body.appendChild(overlay);
    document.body.appendChild(aside);

    function openMenu() { aside.classList.add('is-open'); overlay.classList.add('is-open'); }
    function closeMenu() { aside.classList.remove('is-open'); overlay.classList.remove('is-open'); }
    function toggleMenu() { aside.classList.contains('is-open') ? closeMenu() : openMenu(); }

    btn.addEventListener('click', toggleMenu);
    overlay.addEventListener('click', closeMenu);
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape') closeMenu();
      else if (e.key === 'm' || e.key === 'M') toggleMenu();
    });
  })();

  // Start at hash if present
  const fromHash = parseInt(location.hash.replace('#', ''), 10);
  if (!isNaN(fromHash) && fromHash >= 1 && fromHash <= total) index = fromHash - 1;

  render();
})();
