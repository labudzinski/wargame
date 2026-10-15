(() => {
  'use strict';

  const root = document.documentElement;
  const storageKey = 'wargame-theme';
  const validTheme = (value) => value === 'light' || value === 'dark' || value === 'auto';
  const systemTheme = window.matchMedia('(prefers-color-scheme: dark)');
  let theme;
  try {
    theme = localStorage.getItem(storageKey);
  } catch {
    // Preferences remain optional when browser storage is unavailable.
  }
  if (!validTheme(theme)) {
    theme = 'auto';
  }
  // Apply the theme before stylesheets load to avoid flashing the wrong theme.
  function applyTheme() {
    root.dataset.theme = theme === 'auto' ? (systemTheme.matches ? 'dark' : 'light') : theme;
  }
  applyTheme();
  systemTheme.addEventListener('change', () => {
    if (theme === 'auto') applyTheme();
  });

  function initialize() {
    const switcher = document.querySelector('[data-ds-theme-switcher]');
    if (!switcher) return;
    const buttons = switcher.querySelectorAll('button[data-theme-choice]');
    function render() {
      for (const button of buttons) {
        button.setAttribute('aria-pressed', String(button.dataset.themeChoice === theme));
      }
    }
    for (const button of buttons) {
      button.addEventListener('click', () => {
        const choice = button.dataset.themeChoice;
        if (!validTheme(choice)) return;
        theme = choice;
        applyTheme();
        render();
        try {
          localStorage.setItem(storageKey, theme);
        } catch {
          // Switching still works for this page without persistent storage.
        }
      });
    }
    render();
    switcher.hidden = false;
  }
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initialize, {once: true});
  } else {
    initialize();
  }
})();
