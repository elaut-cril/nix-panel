'use strict';

const NIX_ICON_PATHS = {
  activity: '<path d="M3 12h4l3-8 4 16 3-8h4"/>',
  memory: '<rect x="5" y="6" width="14" height="12" rx="2"/><path d="M9 2v4m6-4v4M9 18v4m6-4v4M2 10h3m14 0h3M2 15h3m14 0h3"/>',
  'hard-drive': '<rect x="3" y="5" width="18" height="13" rx="2"/><path d="M7 14h.01M11 14h.01M3 11h18"/>',
  network: '<rect x="3" y="4" width="18" height="12" rx="2"/><path d="M8 20h8m-4-4v4M7 10h3l2-3 3 6 2-3h2"/>',
  monitor: '<rect x="3" y="4" width="18" height="13" rx="2"/><path d="M8 21h8m-4-4v4"/>',
  chat: '<path d="M20 15a3 3 0 0 1-3 3H9l-5 4v-4a3 3 0 0 1-1-2V6a3 3 0 0 1 3-3h11a3 3 0 0 1 3 3z"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  users: '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/>',
  lock: '<rect x="4" y="10" width="16" height="11" rx="2"/><path d="M8 10V6a4 4 0 0 1 8 0v4m-4 5v2"/>',
  bell: '<path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4"/>',
  settings: '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .34 1.88l.06.06-2.83 2.83-.06-.06a1.7 1.7 0 0 0-1.88-.34 1.7 1.7 0 0 0-1.03 1.56V21h-4v-.08A1.7 1.7 0 0 0 8.94 19.4a1.7 1.7 0 0 0-1.88.34l-.06.06-2.83-2.83.06-.06A1.7 1.7 0 0 0 4.57 15 1.7 1.7 0 0 0 3 14H3v-4h.08A1.7 1.7 0 0 0 4.6 8.94a1.7 1.7 0 0 0-.34-1.88L4.2 7l2.83-2.83.06.06A1.7 1.7 0 0 0 9 4.57 1.7 1.7 0 0 0 10 3V3h4v.08A1.7 1.7 0 0 0 15.06 4.6a1.7 1.7 0 0 0 1.88-.34L17 4.2 19.8 7l-.06.06a1.7 1.7 0 0 0-.34 1.88A1.7 1.7 0 0 0 21 10h.08v4H21a1.7 1.7 0 0 0-1.6 1z"/>',
  terminal: '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="m7 9 3 3-3 3m6 0h4"/>',
  zap: '<path d="M13 2 4 14h7l-1 8 10-13h-7z"/>',
  logout: '<path d="M10 4H5a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h5M14 8l4 4-4 4m4-4H8"/>',
  'arrow-left': '<path d="m15 18-6-6 6-6M9 12h12"/>',
  'arrow-right': '<path d="m9 18 6-6-6-6M3 12h12"/>',
  refresh: '<path d="M20 6v5h-5M4 18v-5h5M18.5 9A7 7 0 0 0 6 6.5L4 11m16 2-2 4.5A7 7 0 0 1 5.5 15"/>',
  search: '<circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/>',
  x: '<path d="M6 6l12 12M18 6 6 18"/>',
  upload: '<path d="M12 16V3m-5 5 5-5 5 5M4 15v5a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-5"/>',
  download: '<path d="M12 3v13m-5-5 5 5 5-5M4 16v4a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-4"/>',
  folder: '<path d="M3 6a2 2 0 0 1 2-2h5l2 3h7a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>',
  'folder-open': '<path d="M3 6a2 2 0 0 1 2-2h5l2 3h7a2 2 0 0 1 2 2v2M3 18l3-8h16l-3 9a2 2 0 0 1-2 1H5a2 2 0 0 1-2-2z"/>',
  file: '<path d="M6 2h8l4 4v16H6zM14 2v5h5M9 12h6m-6 4h6"/>',
  'file-text': '<path d="M6 2h8l4 4v16H6zM14 2v5h5M9 12h6m-6 4h6"/>',
  copy: '<rect x="8" y="8" width="12" height="12" rx="2"/><path d="M16 8V5a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h3"/>',
  scissors: '<circle cx="6" cy="7" r="3"/><circle cx="6" cy="17" r="3"/><path d="m8.5 8.5 12 10.5M8.5 15.5 20.5 5"/>',
  edit: '<path d="m4 16-1 5 5-1L19 9a2.8 2.8 0 0 0-4-4zM13 6l4 4"/>',
  trash: '<path d="M4 7h16M9 7V4h6v3m3 0-1 15H7L6 7m4 4v7m4-7v7"/>',
  archive: '<path d="M4 8v12h16V8M3 3h18v5H3zM10 12h4"/>',
  save: '<path d="M5 3h12l4 4v14H3V3zM8 3v6h8V3M8 21v-8h8v8"/>',
  play: '<path d="m8 5 11 7-11 7z"/>',
  link: '<path d="M10 13a5 5 0 0 0 7 0l3-3a5 5 0 0 0-7-7l-2 2m3 6a5 5 0 0 0-7 0l-3 3a5 5 0 0 0 7 7l2-2"/>',
  paperclip: '<path d="m20 11-8 8a5 5 0 0 1-7-7l8-8a3 3 0 0 1 4 4l-8 8a1 1 0 0 1-1-1l7-7"/>',
  bold: '<path d="M7 4h7a4 4 0 0 1 0 8H7zm0 8h8a4 4 0 0 1 0 8H7zM7 4v16"/>',
  italic: '<path d="M10 4h8M6 20h8M14 4 10 20"/>',
  code: '<path d="m8 6-6 6 6 6m8-12 6 6-6 6M14 4l-4 16"/>',
  'code-block': '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="m8 9-3 3 3 3m8-6 3 3-3 3m-4-7-2 8"/>',
  info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v6m0-10h.01"/>',
  shield: '<path d="M12 2 4 5v6c0 5 3 9 8 11 5-2 8-6 8-11V5z"/><path d="m8 12 3 3 5-6"/>',
  globe: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/>',
  eye: '<path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
  check: '<path d="m5 12 4 4L19 6"/>',
  'chevron-down': '<path d="m6 9 6 6 6-6"/>'
};

function nixIcon(name, className) {
  const paths = Object.prototype.hasOwnProperty.call(NIX_ICON_PATHS, name) ? NIX_ICON_PATHS[name] : NIX_ICON_PATHS.file;
  const safeClass = String(className || '').replace(/[^a-zA-Z0-9 _-]/g, '');
  return '<svg class="nix-icon' + (safeClass ? ' ' + safeClass : '') + '" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">' + paths + '</svg>';
}

window.nixIcon = nixIcon;

NIX_ICON_PATHS.send = '<path d="m3 3 18 9-18 9 4-9zM7 12h14"/>';
function nixHydrateIcons(root) {
  if (!root) return;
  const targets = [];
  if (root.matches && root.matches('[data-icon]')) targets.push(root);
  if (root.querySelectorAll) targets.push(...root.querySelectorAll('[data-icon]'));
  targets.forEach(element => {
    const name = element.dataset.icon;
    element.innerHTML = nixIcon(name);
    element.removeAttribute('data-icon');
    element.classList.add('icon-slot');
  });
}
window.nixHydrateIcons = nixHydrateIcons;
document.addEventListener('DOMContentLoaded', () => {
  nixHydrateIcons(document.body);
  const observer = new MutationObserver(records => {
    records.forEach(record => record.addedNodes.forEach(node => {
      if (node.nodeType === Node.ELEMENT_NODE) nixHydrateIcons(node);
    }));
  });
  observer.observe(document.body, { childList: true, subtree: true });
});
