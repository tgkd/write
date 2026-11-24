const motionAllowed = window.matchMedia('(prefers-reduced-motion: no-preference)').matches;
const animatedSelector = '[data-animate], [data-replay]';

function ownAnimations(element) {
  if (typeof element.getAnimations !== 'function') {
    return [];
  }
  return element
    .getAnimations({ subtree: true })
    .filter((animation) => animation.effect?.target?.closest(animatedSelector) === element);
}

function rewind(element) {
  for (const animation of ownAnimations(element)) {
    animation.pause();
    animation.currentTime = 0;
  }
}

function restart(element) {
  for (const animation of ownAnimations(element)) {
    animation.currentTime = 0;
    animation.play();
  }
}

function watchAnimations() {
  const seen = new WeakSet();
  const observer = new IntersectionObserver(
    (entries) => {
      for (const { target, isIntersecting } of entries) {
        const firstSight = !seen.has(target);
        seen.add(target);
        if (!isIntersecting) {
          rewind(target);
          continue;
        }
        if (!firstSight) {
          restart(target);
        }
        if (!target.hasAttribute('data-replay')) {
          observer.unobserve(target);
        }
      }
    },
    { rootMargin: '0px 0px -6% 0px' },
  );
  for (const element of document.querySelectorAll(animatedSelector)) {
    observer.observe(element);
  }
}

if (motionAllowed && 'IntersectionObserver' in window) {
  watchAnimations();
}
