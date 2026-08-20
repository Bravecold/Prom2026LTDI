const students = [
  ['Sofia','Ramirez','11A','photo-1494790108377-be9c29b29330','12'],['Juan Pablo','Mendez','11A','photo-1500648767791-00dcc994a43e','4'],['Valentina','Perez','11A','photo-1531123897727-8f129e1688ce','9'],['Samuel','Gomez','11A','photo-1506794778202-cad84cf45f1d','7'],
  ['Mariana','Torres','11B','photo-1488426862026-3ee34a7d66df','18'],['Nicolas','Rojas','11B','photo-1507003211169-0a1dd7228f2d','6'],['Laura','Gonzalez','11B','photo-1534528741775-53994a69daeb','11'],['Mateo','Castro','11B','photo-1501196354995-cbb51c65aaea','3'],
  ['Isabella','Vargas','11C','photo-1544005313-94ddf0286df2','15'],['Santiago','Moreno','11C','photo-1519085360753-af0119f7cbe7','8'],['Gabriela','Quintero','11C','photo-1529626455594-4ff0802cfb7e','5'],['Martin','Cortes','11C','photo-1504257432389-52343af06ae3','10']
];
const grid = document.querySelector('#student-grid');
const search = document.querySelector('#search');
let activeFilter = 'todos';
function renderStudents() {
  const query = search.value.toLowerCase();
  const visible = students.filter(([first,last,className]) => (activeFilter === 'todos' || className === activeFilter) && `${first} ${last}`.toLowerCase().includes(query));
  grid.innerHTML = visible.map(([first,last,className,photo,messages], index) => `<article class="student-card" style="animation-delay:${index * 45}ms"><div class="student-photo"><img src="https://images.unsplash.com/${photo}?auto=format&fit=crop&w=700&q=80" alt="Retrato de ${first} ${last}" loading="lazy"></div><div class="student-meta"><div><h3>${first} ${last}</h3><span>${className} · ${messages} mensajes</span></div><button class="student-message login-trigger" aria-label="Dejar mensaje a ${first}">♡</button></div></article>`).join('');
}
document.querySelectorAll('.filter').forEach(button => button.addEventListener('click', () => { document.querySelector('.filter.active').classList.remove('active'); button.classList.add('active'); activeFilter = button.dataset.filter; renderStudents(); }));
search.addEventListener('input', renderStudents);
renderStudents();

const backdrop = document.querySelector('#modal-backdrop');
function openModal() { backdrop.hidden = false; document.body.style.overflow = 'hidden'; backdrop.querySelector('input').focus(); }
function closeModal() { backdrop.hidden = true; document.body.style.overflow = ''; }
document.addEventListener('click', event => { if (event.target.closest('.login-trigger, #contribute-trigger, #memory-trigger')) openModal(); });
document.querySelector('.modal-close').addEventListener('click', closeModal);
backdrop.addEventListener('click', event => { if (event.target === backdrop) closeModal(); });
document.querySelector('#modal-form').addEventListener('submit', event => { event.preventDefault(); document.querySelector('#modal-copy').textContent = 'Listo. En la versión conectada recibirás un enlace para confirmar tu cuenta y comenzar a compartir.'; event.target.innerHTML = '<button class="button button-dark" type="button" onclick="closeModal()">Volver al anuario <span>↗</span></button>'; });