let sliderIndex = 0;
let sliderTimer = null;

function showSlide(i) {
  const slides = document.querySelectorAll('.slide');
  if (!slides.length) return;
  sliderIndex = (i + slides.length) % slides.length;
  slides.forEach((el, idx) => el.classList.toggle('active', idx === sliderIndex));
}

function nextSlide() {
  showSlide(sliderIndex + 1);
}

function prevSlide() {
  showSlide(sliderIndex - 1);
}

function startSlider() {
  showSlide(0);
  if (sliderTimer) clearInterval(sliderTimer);
  sliderTimer = setInterval(nextSlide, 3000);
}

function toast(msg) {
  const el = document.getElementById('toast');
  if (!el) return;
  el.textContent = msg;
  el.classList.add('show');
  setTimeout(() => el.classList.remove('show'), 2600);
}

document.addEventListener('DOMContentLoaded', () => {
  startSlider();
  document.querySelectorAll('[data-toast]').forEach((b) => {
    b.addEventListener('click', () => toast(b.dataset.toast || 'Готово'));
  });
});
