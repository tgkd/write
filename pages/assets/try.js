const svgNamespace = 'http://www.w3.org/2000/svg';
const boxSize = 109;
const sampleCount = 48;
const shapeLimit = 0.55;
const smallestSizeRatio = 0.45;
const largestSizeRatio = 2.2;
const guidedPositionLimit = 0.1;
const freePositionLimit = 0.14;
const shortestStroke = 2;
const smallestShapeSize = 7;
const pointSpacing = 0.35;
const feedbackDuration = 2600;
const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');

function distance(a, b) {
  return Math.hypot(a.x - b.x, a.y - b.y);
}

function polylineLength(points) {
  let total = 0;
  for (let index = 1; index < points.length; index += 1) {
    total += distance(points[index - 1], points[index]);
  }
  return total;
}

function resample(points, count = sampleCount) {
  if (points.length < 2) {
    return Array.from({ length: count }, () => ({ ...points[0] }));
  }
  const total = polylineLength(points);
  const result = [{ ...points[0] }];
  let segment = 1;
  let travelled = 0;
  for (let index = 1; index < count - 1; index += 1) {
    const target = (total * index) / (count - 1);
    while (segment < points.length - 1 && travelled + distance(points[segment - 1], points[segment]) < target) {
      travelled += distance(points[segment - 1], points[segment]);
      segment += 1;
    }
    const start = points[segment - 1];
    const end = points[segment];
    const length = distance(start, end);
    const ratio = length > 0 ? Math.min(1, (target - travelled) / length) : 0;
    result.push({ x: start.x + (end.x - start.x) * ratio, y: start.y + (end.y - start.y) * ratio });
  }
  result.push({ ...points[points.length - 1] });
  return result;
}

function centroid(points) {
  const sum = points.reduce((total, point) => ({ x: total.x + point.x, y: total.y + point.y }), { x: 0, y: 0 });
  return { x: sum.x / points.length, y: sum.y / points.length };
}

function rmsSize(points, center) {
  const squares = points.reduce((total, point) => total + (point.x - center.x) ** 2 + (point.y - center.y) ** 2, 0);
  return Math.sqrt(squares / points.length);
}

function normalize(points) {
  const center = centroid(points);
  const size = Math.max(rmsSize(points, center), smallestShapeSize);
  return points.map((point) => ({ x: (point.x - center.x) / size, y: (point.y - center.y) / size }));
}

function frechet(first, second) {
  let previous = new Array(second.length).fill(Infinity);
  for (let row = 0; row < first.length; row += 1) {
    const current = new Array(second.length);
    for (let column = 0; column < second.length; column += 1) {
      const gap = distance(first[row], second[column]);
      let reach;
      if (row === 0 && column === 0) {
        reach = gap;
      } else if (row === 0) {
        reach = current[column - 1];
      } else if (column === 0) {
        reach = previous[0];
      } else {
        reach = Math.min(previous[column], previous[column - 1], current[column - 1]);
      }
      current[column] = Math.max(reach, gap);
    }
    previous = current;
  }
  return previous[second.length - 1];
}

function compareStroke(drawn, reference, positionLimit) {
  const drawnCenter = centroid(drawn);
  const referenceCenter = centroid(reference);
  const positionPassed = distance(drawnCenter, referenceCenter) / boxSize <= positionLimit;
  const sizeRatio = rmsSize(drawn, drawnCenter) / rmsSize(reference, referenceCenter);
  const sizePassed = sizeRatio >= smallestSizeRatio && sizeRatio <= largestSizeRatio;
  const placed = positionPassed && sizePassed;
  const shape = normalize(drawn);
  const forward = frechet(shape, normalize(reference));
  const backward = frechet(shape, normalize([...reference].reverse()));
  return {
    matches: placed && forward <= shapeLimit,
    reversed: placed && backward <= shapeLimit && backward < forward,
  };
}

function judgeStroke(drawnPoints, referenceSamples, expectedIndex, guided) {
  if (polylineLength(drawnPoints) < shortestStroke) {
    return 'ignored';
  }
  const drawn = resample(drawnPoints);
  const positionLimit = guided ? guidedPositionLimit : freePositionLimit;
  const [expected, ...later] = referenceSamples
    .slice(expectedIndex)
    .map((reference) => compareStroke(drawn, reference, positionLimit));
  if (expected.matches) {
    return 'accepted';
  }
  if (expected.reversed) {
    return 'wrongDirection';
  }
  if (later.some((result) => result.matches)) {
    return 'wrongOrder';
  }
  if (later.some((result) => result.reversed)) {
    return 'wrongDirection';
  }
  return 'wrongShape';
}

function fill(template, values) {
  return template.replace(/\{(\w+)\}/g, (match, key) => (key in values ? String(values[key]) : match));
}

function samplePath(path) {
  const length = path.getTotalLength();
  return Array.from({ length: sampleCount }, (unused, index) => {
    const point = path.getPointAtLength((length * index) / (sampleCount - 1));
    return { x: point.x, y: point.y };
  });
}

function smoothPathData(points) {
  if (points.length === 1) {
    const [point] = points;
    return `M${point.x},${point.y}l0.01,0`;
  }
  let data = `M${points[0].x},${points[0].y}`;
  for (let index = 1; index < points.length - 1; index += 1) {
    const point = points[index];
    const next = points[index + 1];
    data += `Q${point.x},${point.y} ${(point.x + next.x) / 2},${(point.y + next.y) / 2}`;
  }
  const last = points[points.length - 1];
  return `${data}L${last.x},${last.y}`;
}

function createPath(className, data) {
  const path = document.createElementNS(svgNamespace, 'path');
  path.setAttribute('class', className);
  path.setAttribute('d', data);
  path.setAttribute('pathLength', '1');
  return path;
}

function afterAnimation(element, callback) {
  const running = !reducedMotion.matches && getComputedStyle(element).animationName !== 'none';
  if (!running) {
    callback();
    return;
  }
  element.addEventListener('animationend', callback, { once: true });
}

function startDemo(root) {
  const { characters, strings } = JSON.parse(root.querySelector('.try-data').textContent);
  const board = root.querySelector('.try-board');
  const ink = root.querySelector('.try-ink');
  const written = root.querySelector('.try-written');
  const trail = root.querySelector('.try-trail');
  const startDot = root.querySelector('.try-start');
  const feedback = root.querySelector('.try-feedback');
  const instruction = root.querySelector('.try-instruction');
  const guides = [...root.querySelectorAll('.try-guide')];
  const buttons = Object.fromEntries(
    [...root.querySelectorAll('[data-action]')].map((button) => [button.dataset.action, button]),
  );

  const state = {
    characterIndex: 0,
    expected: 0,
    guided: true,
    busy: false,
    generation: 0,
    references: [],
    pathData: [],
    pointerId: null,
    points: [],
    line: null,
    feedbackTimer: 0,
  };

  const total = () => state.references.length;
  const complete = () => state.expected >= total();

  function hideFeedback() {
    window.clearTimeout(state.feedbackTimer);
    feedback.classList.remove('is-visible');
  }

  function showFeedback(text, tone) {
    window.clearTimeout(state.feedbackTimer);
    feedback.textContent = text;
    feedback.dataset.tone = tone;
    feedback.dataset.place = !complete() && state.references[state.expected][0].y < boxSize / 2 ? 'bottom' : 'top';
    feedback.classList.add('is-visible');
    state.feedbackTimer = window.setTimeout(hideFeedback, feedbackDuration);
  }

  function updateStartDot() {
    const visible = state.guided && !state.busy && !complete();
    if (!visible) {
      startDot.setAttribute('visibility', 'hidden');
      return;
    }
    const [start] = state.references[state.expected];
    startDot.setAttribute('cx', String(start.x));
    startDot.setAttribute('cy', String(start.y));
    startDot.setAttribute('visibility', 'visible');
  }

  function updateStatus() {
    instruction.textContent = complete()
      ? fill(strings.done, { total: total() })
      : fill(strings.instruction, { current: state.expected + 1, total: total() });
    root.classList.toggle('is-complete', complete());
    buttons.next.classList.toggle('button-primary', complete());
    buttons.next.classList.toggle('button-quiet', !complete());
    if (complete() && document.activeElement === buttons.hint) {
      buttons.next.focus();
    }
    buttons.hint.disabled = complete();
    updateStartDot();
  }

  function clearDrawing() {
    state.generation += 1;
    state.busy = false;
    state.expected = 0;
    state.pointerId = null;
    state.line = null;
    written.replaceChildren();
    trail.replaceChildren();
    hideFeedback();
  }

  function showCharacter(index) {
    clearDrawing();
    state.characterIndex = index;
    const character = characters[index];
    guides.forEach((guide) => {
      guide.hidden = guide.dataset.character !== character;
    });
    const paths = [...guides.find((guide) => !guide.hidden).querySelectorAll('.glyph-stroke')];
    state.pathData = paths.map((path) => path.getAttribute('d'));
    state.references = paths.map(samplePath);
    board.setAttribute('aria-label', fill(strings.canvasLabel, { character }));
    updateStatus();
  }

  function writeStroke(className) {
    const stroke = createPath(`try-written-stroke ${className}`, state.pathData[state.expected]);
    written.append(stroke);
    state.expected += 1;
    return stroke;
  }

  function retireLine(line, className) {
    line.classList.add(className);
    afterAnimation(line, () => line.remove());
  }

  function accept(line) {
    writeStroke('is-snapping');
    retireLine(line, 'is-accepted');
    showFeedback(strings.accepted, 'accepted');
    updateStatus();
  }

  function reject(line, verdict) {
    const message =
      verdict === 'wrongOrder' ? fill(strings.wrongOrder, { current: state.expected + 1 }) : strings[verdict];
    showFeedback(message, 'rejected');
    line.classList.add('is-rejected');
    if (!reducedMotion.matches) {
      afterAnimation(line, () => line.remove());
    }
  }

  function boxPoint(event) {
    const bounds = ink.getBoundingClientRect();
    return {
      x: ((event.clientX - bounds.left) / bounds.width) * boxSize,
      y: ((event.clientY - bounds.top) / bounds.height) * boxSize,
    };
  }

  function addPoint(point) {
    const last = state.points[state.points.length - 1];
    if (!last || distance(last, point) >= pointSpacing) {
      state.points.push(point);
    }
  }

  function endStroke(event, judged) {
    if (event.pointerId !== state.pointerId) {
      return;
    }
    state.pointerId = null;
    const line = state.line;
    state.line = null;
    if (!judged) {
      line.remove();
      return;
    }
    addPoint(boxPoint(event));
    const verdict = judgeStroke(state.points, state.references, state.expected, state.guided);
    if (verdict === 'ignored') {
      line.remove();
    } else if (verdict === 'accepted') {
      accept(line);
    } else {
      reject(line, verdict);
    }
  }

  board.addEventListener('pointerdown', (event) => {
    if (state.busy || state.pointerId !== null || complete() || !event.isPrimary) {
      return;
    }
    if (event.pointerType === 'mouse' && event.button !== 0) {
      return;
    }
    event.preventDefault();
    board.setPointerCapture(event.pointerId);
    hideFeedback();
    trail.querySelectorAll('.is-rejected').forEach((line) => line.remove());
    state.pointerId = event.pointerId;
    state.points = [boxPoint(event)];
    state.line = createPath('try-ink-line', smoothPathData(state.points));
    trail.append(state.line);
  });

  board.addEventListener('pointermove', (event) => {
    if (event.pointerId !== state.pointerId) {
      return;
    }
    const events = event.getCoalescedEvents ? event.getCoalescedEvents() : [];
    (events.length > 0 ? events : [event]).forEach((sample) => addPoint(boxPoint(sample)));
    state.line.setAttribute('d', smoothPathData(state.points));
  });

  board.addEventListener('pointerup', (event) => endStroke(event, true));
  board.addEventListener('pointercancel', (event) => endStroke(event, false));

  buttons.hint.addEventListener('click', () => {
    if (state.busy || complete()) {
      return;
    }
    if (state.pointerId !== null) {
      state.line.remove();
      state.line = null;
      state.pointerId = null;
    }
    hideFeedback();
    state.busy = true;
    const generation = state.generation;
    const stroke = writeStroke('is-drawing');
    updateStartDot();
    afterAnimation(stroke, () => {
      if (generation !== state.generation) {
        return;
      }
      state.busy = false;
      stroke.classList.remove('is-drawing');
      updateStatus();
    });
  });

  buttons.guide.addEventListener('click', () => {
    state.guided = !state.guided;
    root.classList.toggle('is-guide-off', !state.guided);
    buttons.guide.setAttribute('aria-pressed', String(state.guided));
    buttons.guide.textContent = state.guided ? strings.guideOn : strings.guideOff;
    updateStartDot();
  });

  buttons.reset.addEventListener('click', () => {
    clearDrawing();
    updateStatus();
  });

  buttons.next.addEventListener('click', () => {
    showCharacter((state.characterIndex + 1) % characters.length);
  });

  root.classList.add('try-ready');
  showCharacter(0);
}

document.querySelectorAll('[data-try]').forEach(startDemo);
