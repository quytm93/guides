// ---- Shared content sidebar (decks + glossary pages) ----
// Single source of truth for the lesson list. Works from both the site root
// (glossary-*.html) and the lessons/ folder (cs-*.html, bai-2, perf-1) by
// computing path prefixes from the current location.
(function () {
  'use strict';

  const inLessons = /\/lessons\//.test(location.pathname);
  const R = inLessons ? '../' : '';        // prefix to reach the site root
  const L = inLessons ? '' : 'lessons/';   // prefix to reach the lessons/ folder

  const LESSONS = [
    { n: '🧰', file: L + 'bai-2.html', title: 'Chuẩn bị · Cài đặt Xcode 26' },
    { n: 'G1', file: R + 'glossary-ios.html', title: 'Thuật ngữ iOS & Swift' },
    { n: 'G2', file: R + 'glossary-swiftui.html', title: 'Thuật ngữ SwiftUI' },
    { n: 'C1', file: L + 'cs-1.html', title: 'CS-1: AI Photo Editor' },
    { n: 'C2', file: L + 'cs-2.html', title: 'CS-2: Short-Video Editor' },
    { n: 'C3', file: L + 'cs-3.html', title: 'CS-3: Music Streaming' },
    { n: 'C4', file: L + 'cs-4.html', title: 'CS-4: Meditation & Sleep' },
    { n: 'C5', file: L + 'cs-5.html', title: 'CS-5: E-commerce / Retail' },
    { n: 'C6', file: L + 'cs-6.html', title: 'CS-6: Personal Finance' },
    { n: 'C7', file: L + 'cs-7.html', title: 'CS-7: Food Delivery' },
    { n: 'C8', file: L + 'cs-8.html', title: 'CS-8: Ride-Hailing' },
    { n: 'C9', file: L + 'cs-9.html', title: 'CS-9: Social Photo Feed' },
    { n: 'C10', file: L + 'cs-10.html', title: 'CS-10: Dating' },
    { n: 'C11', file: L + 'cs-11.html', title: 'CS-11: News & Reading' },
    { n: 'C12', file: L + 'cs-12.html', title: 'CS-12: Casual Mobile Game' },
    { n: 'C13', file: L + 'cs-13.html', title: 'CS-13: Habit & Fitness Tracker' },
    { n: 'C14', file: L + 'cs-14.html', title: 'CS-14: Language Learning' },
    { n: 'C15', file: L + 'cs-15.html', title: 'CS-15: Notes & Productivity' },
    { n: 'C16', file: L + 'cs-16.html', title: 'CS-16: Kids Education' },
    { n: 'C17', file: L + 'cs-17.html', title: 'CS-17: AR Furniture & Measure' },
    { n: 'C18', file: L + 'cs-18.html', title: 'CS-18: Smart-Home Companion' },
    { n: 'C19', file: L + 'cs-19.html', title: 'CS-19: Enterprise Field App' },
    { n: 'C20', file: L + 'cs-20.html', title: 'CS-20: AI Chat Assistant' },
    { n: 'P3', file: L + 'perf-1.html', title: 'Phần 3: Hiệu năng & Sự cố' },
  ];

  const here = location.pathname.split('/').pop() || 'index.html';
  const helpPanel = document.getElementById('helpPanel'); // exists on decks only

  // The floating home button (if any) is replaced by this menu
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
    '<a class="sidebar-home" href="' + R + 'index.html">⌂ Trang chủ</a>' +
    '<div class="sidebar-head">Nội dung khóa học</div>' +
    '<nav class="sidebar-list">' +
    LESSONS.map(function (l) {
      const active = l.file.split('/').pop() === here ? ' is-active' : '';
      return '<a class="sidebar-item' + active + '" href="' + l.file + '">' +
        '<span class="sidebar-num">' + l.n + '</span>' +
        '<span>' + l.title + '</span></a>';
    }).join('') +
    '</nav>';

  document.body.appendChild(btn);
  document.body.appendChild(overlay);
  document.body.appendChild(aside);

  function openMenu() { aside.classList.add('is-open'); overlay.classList.add('is-open'); }
  function closeMenu() { aside.classList.remove('is-open'); overlay.classList.remove('is-open'); }
  function toggleMenu() { aside.classList.contains('is-open') ? closeMenu() : openMenu(); }

  btn.addEventListener('click', toggleMenu);
  overlay.addEventListener('click', closeMenu);
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') {
      // On decks, if the help panel is open let it close first (slideshow.js
      // handles that and stops this handler); otherwise toggle the sidebar.
      if (helpPanel && !helpPanel.hidden) return;
      toggleMenu();
    } else if (e.key === 'm' || e.key === 'M') toggleMenu();
  });
})();
