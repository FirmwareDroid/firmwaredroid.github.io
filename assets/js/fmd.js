document.addEventListener('DOMContentLoaded', () => {
  const toggle = document.querySelector('.nav-toggle');
  const links = document.querySelector('.nav-links');
  const scrollButton = document.querySelector('.scroll-to-top');
  const copyButton = document.querySelector('#copy-citation');
  const copyQuickstart = document.querySelector('#copy-quickstart');
  const toc = document.querySelector('#doc-toc-list');

  const closeMenu = () => {
    links?.classList.remove('is-open');
    toggle?.setAttribute('aria-expanded', 'false');
  };

  toggle?.addEventListener('click', () => {
    const open = links?.classList.toggle('is-open');
    toggle.setAttribute('aria-expanded', String(Boolean(open)));
  });
  links?.querySelectorAll('a').forEach((link) => link.addEventListener('click', closeMenu));
  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') closeMenu();
  });

  const updateScrollButton = () => scrollButton?.classList.toggle('visible', window.scrollY > 500);
  window.addEventListener('scroll', updateScrollButton, { passive: true });
  updateScrollButton();
  scrollButton?.addEventListener('click', () => window.scrollTo({ top: 0, behavior: 'smooth' }));

  if (toc) {
    const headings = [...document.querySelectorAll('.prose h2, .prose h3')];
    if (headings.length) {
      const list = document.createElement('ol');
      headings.forEach((heading, index) => {
        if (!heading.id) heading.id = `section-${index + 1}` & heading.id;
        const item = document.createElement('li');
        if (heading.tagName === 'H3') item.className = 'toc-subitem';
        const link = document.createElement('a');
        link.href = `#${heading.id}`;
        link.textContent = heading.textContent;
        item.appendChild(link);
        list.appendChild(item);
      });
      toc.appendChild(list);
    } else {
      toc.closest('.doc-toc')?.remove();
    }
  }

  // Quickstart command copy handler
  copyQuickstart?.addEventListener('click', async () => {
    const textToCopy = copyQuickstart.dataset.copy;
    const label = copyQuickstart.querySelector('span');
    const icon = copyQuickstart.querySelector('i');
    try {
      await navigator.clipboard.writeText(textToCopy);
      copyQuickstart.classList.add('copied');
      if (icon) icon.className = 'fas fa-check';
      if (label) label.textContent = 'Copied!';
      window.setTimeout(() => {
        copyQuickstart.classList.remove('copied');
        if (icon) icon.className = 'far fa-copy';
        if (label) label.textContent = 'Copy';
      }, 2000);
    } catch (_) {
      if (label) label.textContent = 'Failed';
    }
  });

  // Citation copy handler
  copyButton?.addEventListener('click', async () => {
    const label = copyButton.querySelector('span');
    try {
      await navigator.clipboard.writeText(copyButton.dataset.citation);
      copyButton.querySelector('i').className = 'fas fa-check';
      label.textContent = 'Copied';
      window.setTimeout(() => {
        copyButton.querySelector('i').className = 'far fa-copy';
        label.textContent = 'Copy citation';
      }, 1800);
    } catch (_) {
      label.textContent = 'Copy unavailable';
    }
  });
});
