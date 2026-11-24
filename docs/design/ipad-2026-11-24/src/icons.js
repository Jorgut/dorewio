const ICONS = {
  note: '<path d="M9 18V5l10-2v13"/><circle cx="6.5" cy="18" r="2.5"/><circle cx="16.5" cy="16" r="2.5"/>',
  grid: '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
  tap: '<path d="M9 11V5a1.5 1.5 0 0 1 3 0v4"/><path d="M12 9V4.5a1.5 1.5 0 0 1 3 0V10"/><path d="M15 10V6.5a1.5 1.5 0 0 1 3 0V13c0 4-2.5 7-6 7s-6-3-6-7v-1"/>',
  ear: '<path d="M6 9a6 6 0 1 1 12 0c0 3-2 4-3.5 6S12 20 12 21"/><path d="M9 9a3 3 0 0 1 6 0c0 2-2 2.5-2 4"/>',
  fork: '<path d="M8 3v5a4 4 0 0 0 8 0V3"/><path d="M12 12v9"/>',
  metronome: '<path d="M9 3h6l4 18H5L9 3z"/><path d="M12 21V9"/><path d="M12 9l4-3"/>',
  rhythm: '<path d="M3 12h3l2-5 3 11 2-7 2 4h6"/>',
  bow: '<path d="M5 19 19 5"/><path d="M15 5h4v4"/>',
  vibrato: '<path d="M2 12c2-6 4-6 6 0s4 6 6 0 4-6 6 0"/>',
  pdf: '<path d="M7 3h7l4 4v14H7z"/><path d="M14 3v4h4"/><path d="M10 12h6M10 16h6"/>',
  audio: '<path d="M3 12v0"/><path d="M6 8v8M9 5v14M12 9v6M15 6v12M18 10v4M21 12v0"/>',
  bulb: '<path d="M9 18h6"/><path d="M10 21h4"/><path d="M12 3a6 6 0 0 0-4 10c1 1 1.5 2 1.5 3h5c0-1 .5-2 1.5-3a6 6 0 0 0-4-10z"/>',
  target: '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="4"/><circle cx="12" cy="12" r="1"/>',
  plus: '<path d="M12 5v14M5 12h14"/>'
};
document.querySelectorAll('[data-icon]').forEach(el => {
  const path = ICONS[el.dataset.icon];
  if (!path) return;
  el.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">' + path + '</svg>';
});
