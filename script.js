const API_BASE_URL = (window.APP_CONFIG?.API_BASE_URL || 'http://localhost:8000').replace(/\/$/, '');
const grid = document.querySelector('#student-grid');
const search = document.querySelector('#search');
let activeFilter = 'todos';
let students = [];
let accessToken = localStorage.getItem('prom2026_token');

async function apiFetch(path, options = {}) {
  const headers = new Headers(options.headers || {});
  if (accessToken) headers.set('Authorization', `Bearer ${accessToken}`);
  const response = await fetch(`${API_BASE_URL}${path}`, { ...options, headers });
  if (!response.ok) throw new Error((await response.json().catch(() => ({}))).detail || 'No fue posible conectar con el anuario');
  return response.status === 204 ? null : response.json();
}

function normalizedStudents(records) {
  return records.map(student => {
    const [first, ...lastParts] = student.name.split(' ');
    return [first, lastParts.join(' '), student.classroom, student.photo_url || 'photo-1494790108377-be9c29b29330', '0'];
  });
}

async function loadStudents() {
  try {
    const records = await apiFetch('/api/students');
    if (records.length) students = normalizedStudents(records);
  } catch (error) { console.info('Galeria no disponible:', error.message); }
  renderStudents();
}

function unlockSite() {
  document.body.classList.remove('auth-locked');
  document.querySelector('#auth-gate').hidden = true;
  loadStudents();
}

async function authenticate(email, password) {
  const body = new URLSearchParams({ username: email, password });
  const result = await apiFetch('/api/auth/login', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body });
  accessToken = result.access_token;
  localStorage.setItem('prom2026_token', accessToken);
  unlockSite();
}

function renderStudents() {
  const query = search.value.toLowerCase();
  const visible = students.filter(([first, last, className]) => (activeFilter === 'todos' || className === activeFilter) && `${first} ${last}`.toLowerCase().includes(query));
  grid.innerHTML = visible.map(([first, last, className, photo, messages], index) => `<article class="student-card" style="animation-delay:${index * 45}ms"><div class="student-photo"><img src="${photo.startsWith('http') ? photo : `https://images.unsplash.com/${photo}?auto=format&fit=crop&w=700&q=80`}" alt="Retrato de ${first} ${last}" loading="lazy"></div><div class="student-meta"><div><h3>${first} ${last}</h3><span>${className} · ${messages} mensajes</span></div><button class="student-message login-trigger" aria-label="Dejar mensaje a ${first}">♡</button></div></article>`).join('');
}

document.querySelectorAll('.filter').forEach(button => button.addEventListener('click', () => { document.querySelector('.filter.active').classList.remove('active'); button.classList.add('active'); activeFilter = button.dataset.filter; renderStudents(); }));
search.addEventListener('input', renderStudents);
if (accessToken) {
  apiFetch('/api/auth/me').then(unlockSite).catch(() => { accessToken = null; localStorage.removeItem('prom2026_token'); });
}

document.querySelector('#access-form').addEventListener('submit', async event => {
  event.preventDefault();
  const form = new FormData(event.target);
  const status = document.querySelector('#auth-status');
  status.textContent = 'Verificando acceso...';
  try {
    await authenticate(form.get('email'), form.get('password'));
  } catch (error) {
    status.textContent = error.message;
  }
});
document.querySelector('#access-register').addEventListener('click', openModal);

const backdrop = document.querySelector('#modal-backdrop');
function openModal() { backdrop.hidden = false; document.body.style.overflow = 'hidden'; backdrop.querySelector('input').focus(); }
function closeModal() { backdrop.hidden = true; document.body.style.overflow = ''; }
document.addEventListener('click', event => { if (event.target.closest('.login-trigger, #contribute-trigger, #memory-trigger')) openModal(); });
document.querySelector('.modal-close').addEventListener('click', closeModal);
backdrop.addEventListener('click', event => { if (event.target === backdrop) closeModal(); });
document.querySelector('#modal-form').addEventListener('submit', async event => {
  event.preventDefault();
  const form = new FormData(event.target);
  const submit = event.target.querySelector('button');
  submit.disabled = true;
  try {
    const result = await apiFetch('/api/auth/register', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ name: form.get('name'), email: form.get('email'), password: form.get('password') }) });
    document.querySelector('#modal-copy').textContent = `Solicitud recibida para ${result.name}. El equipo del colegio revisará tu autorización antes de habilitar el acceso.`;
    event.target.innerHTML = '<button class="button button-dark" type="button" onclick="closeModal()">Volver al inicio <span>↗</span></button>';
  } catch (error) {
    document.querySelector('#modal-copy').textContent = error.message;
    submit.disabled = false;
  }
});
