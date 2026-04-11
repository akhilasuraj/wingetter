/* ════════════════════════════════════════════
   Winget-UI — main.js
   All scripts are non-blocking and initialised
   after DOMContentLoaded.
════════════════════════════════════════════ */

(function () {
  'use strict';

  /* ── COPY COMMAND ─────────────────────────── */
  const IRM_COMMAND =
    'irm "https://gist.githubusercontent.com/akhilasuraj/1003be9675118c0ac5db3e76edcb37b8/raw/winget-ui.ps1" | iex';

  function copyToClipboard(text, onSuccess) {
    if (!navigator.clipboard) {
      // Fallback for older browsers / non-HTTPS
      const area = document.createElement('textarea');
      area.value = text;
      area.style.cssText = 'position:fixed;top:-9999px;left:-9999px;opacity:0';
      document.body.appendChild(area);
      area.select();
      try { document.execCommand('copy'); onSuccess(); } catch (_) {}
      document.body.removeChild(area);
      return;
    }
    navigator.clipboard.writeText(text).then(onSuccess).catch(function () {});
  }

  function setButtonCopied(btn) {
    const icon = btn.querySelector('.material-symbols-outlined');
    const label = btn.querySelector('span:last-child') || btn;
    btn.classList.add('copied');
    if (icon) icon.textContent = 'check';
    const origLabel = label.textContent;
    label.textContent = 'Copied!';
    setTimeout(function () {
      btn.classList.remove('copied');
      if (icon) icon.textContent = 'content_copy';
      label.textContent = origLabel;
    }, 2000);
  }

  /* Copy button inside the code block */
  const copyBtn = document.getElementById('copyBtn');
  if (copyBtn) {
    copyBtn.addEventListener('click', function () {
      copyToClipboard(IRM_COMMAND, function () { setButtonCopied(copyBtn); });
    });
  }

  /* Hero "Copy Run Command" button */
  const heroCopy = document.getElementById('heroCopy');
  if (heroCopy) {
    heroCopy.addEventListener('click', function () {
      const btnLabel = heroCopy.querySelector('.btn-label');
      const btnCopied = heroCopy.querySelector('.btn-label-copied');
      const icon = heroCopy.querySelector('.material-symbols-outlined');
      copyToClipboard(IRM_COMMAND, function () {
        if (btnLabel)  btnLabel.setAttribute('hidden', '');
        if (btnCopied) btnCopied.removeAttribute('hidden');
        if (icon) icon.textContent = 'check';
        setTimeout(function () {
          if (btnLabel)  btnLabel.removeAttribute('hidden');
          if (btnCopied) btnCopied.setAttribute('hidden', '');
          if (icon) icon.textContent = 'content_copy';
        }, 2000);
      });
    });
  }

  /* ── NAVBAR SCROLL EFFECT ─────────────────── */
  var navbar = document.getElementById('navbar');
  if (navbar) {
    var onScroll = function () {
      if (window.scrollY > 16) {
        navbar.classList.add('scrolled');
      } else {
        navbar.classList.remove('scrolled');
      }
    };
    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll(); // run once on load
  }

  /* ── MOBILE MENU TOGGLE ───────────────────── */
  var navToggle = document.getElementById('navToggle');
  var navMobile = document.getElementById('navMobile');
  if (navToggle && navMobile) {
    navToggle.addEventListener('click', function () {
      var open = navMobile.classList.toggle('open');
      navToggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    });

    // Close menu when a mobile link is clicked
    navMobile.querySelectorAll('.nav-mobile-link').forEach(function (link) {
      link.addEventListener('click', function () {
        navMobile.classList.remove('open');
        navToggle.setAttribute('aria-expanded', 'false');
      });
    });
  }

  /* ── ACTIVE NAV LINK ON SCROLL ────────────── */
  var sections = document.querySelectorAll('section[id], .hero[id]');
  var navLinks = document.querySelectorAll('.nav-links a[href^="#"]');

  if (sections.length && navLinks.length) {
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          var id = entry.target.getAttribute('id');
          navLinks.forEach(function (link) {
            if (link.getAttribute('href') === '#' + id) {
              link.style.color = 'var(--text)';
            } else {
              link.style.color = '';
            }
          });
        }
      });
    }, { threshold: 0.35 });

    sections.forEach(function (s) { observer.observe(s); });
  }

  /* ── CARD ENTRANCE ANIMATIONS ─────────────── */
  if ('IntersectionObserver' in window) {
    var cards = document.querySelectorAll('.feature-card, .step-card, .qs-step');
    cards.forEach(function (card) {
      card.style.opacity = '0';
      card.style.transform = 'translateY(16px)';
      card.style.transition = 'opacity 0.45s ease, transform 0.45s ease';
    });

    var cardObserver = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.style.opacity = '1';
          entry.target.style.transform = 'translateY(0)';
          cardObserver.unobserve(entry.target);
        }
      });
    }, { threshold: 0.12 });

    cards.forEach(function (card) { cardObserver.observe(card); });
  }

}());
