// ── Slider ──────────────────────────────────────────────
let sliderIndex = 0;
let sliderTimer = null;

function showSlide(i) {
  const slides = document.querySelectorAll('.slide');
  const dots   = document.querySelectorAll('.slider-dot');
  if (!slides.length) return;
  sliderIndex = (i + slides.length) % slides.length;
  slides.forEach((el, idx) => el.classList.toggle('active', idx === sliderIndex));
  dots.forEach((d, idx)  => d.classList.toggle('active',  idx === sliderIndex));
}

function nextSlide() { showSlide(sliderIndex + 1); }
function prevSlide()  { showSlide(sliderIndex - 1); }

function startSlider() {
  showSlide(0);
  if (sliderTimer) clearInterval(sliderTimer);
  sliderTimer = setInterval(nextSlide, 3000);
}

// ── Toast ────────────────────────────────────────────────
function toast(msg) {
  const el = document.getElementById('toast');
  if (!el) return;
  el.textContent = msg;
  el.classList.add('show');
  setTimeout(() => el.classList.remove('show'), 2600);
}

// ── Inline form validation ───────────────────────────────
function fieldError(input, msg) {
  input.classList.add('input-invalid');
  const span = input.parentElement.querySelector('.field-error');
  if (span) span.textContent = msg;
}

function fieldClear(input) {
  input.classList.remove('input-invalid');
  const span = input.parentElement.querySelector('.field-error');
  if (span) span.textContent = '';
}

function validateForm(form) {
  let ok = true;
  form.querySelectorAll('input[required], select[required]').forEach(input => {
    fieldClear(input);
    const val = input.value.trim();
    if (!val) {
      fieldError(input, 'Обязательное поле');
      ok = false;
    } else if (input.type === 'email' && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(val)) {
      fieldError(input, 'Введите корректный email');
      ok = false;
    } else if (input.pattern) {
      const re = new RegExp(`^(?:${input.pattern})$`);
      if (!re.test(val)) {
        fieldError(input, input.title || 'Неверный формат');
        ok = false;
      }
    } else if (input.minLength > 0 && val.length < input.minLength) {
      fieldError(input, `Минимум ${input.minLength} символов`);
      ok = false;
    }
  });
  return ok;
}

// ── Init ─────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
  // Slider init + pause on hover
  const sliderEl = document.querySelector('.slider');
  if (sliderEl) {
    startSlider();
    sliderEl.addEventListener('mouseenter', () => {
      clearInterval(sliderTimer);
      sliderTimer = null;
    });
    sliderEl.addEventListener('mouseleave', () => {
      if (!sliderTimer) sliderTimer = setInterval(nextSlide, 3000);
    });
  }

  // Toast on data-toast elements (skip form submit buttons — they cause page reload)
  document.querySelectorAll('[data-toast]:not([type="submit"])').forEach(el => {
    el.addEventListener('click', () => toast(el.dataset.toast || 'Готово'));
  });

  // Custom inline form validation
  document.querySelectorAll('form[data-validate]').forEach(form => {
    form.addEventListener('submit', e => {
      if (!validateForm(form)) {
        e.preventDefault();
        const first = form.querySelector('.input-invalid');
        if (first) first.focus();
      } else {
        const btn = form.querySelector('[type="submit"]');
        if (btn && btn.dataset.toast) toast(btn.dataset.toast);
      }
    });
    // Clear error on input
    form.querySelectorAll('input, select').forEach(input => {
      input.addEventListener('input', () => fieldClear(input));
    });
  });
});
