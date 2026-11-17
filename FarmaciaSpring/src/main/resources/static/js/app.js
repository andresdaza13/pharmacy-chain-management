/*
 * Comportamiento común a todas las páginas (principios de usabilidad / HCI aplicados):
 *  1. Menú "Más" en el celular (hoja que sube desde abajo, como en iOS).
 *  2. Confirmaciones con un diálogo propio, claro y accesible (en vez de confirm() del navegador):
 *     la acción destructiva va en ROJO y el foco inicial queda en "Cancelar" (prevención de errores).
 *  3. Mensajes de éxito como "toast" que se ocultan solos (retroalimentación sin interrumpir).
 *  4. Evita el doble envío de formularios (doble clic = venta duplicada).
 *  5. Registro del service worker (PWA).
 */
(function () {
    // ---------- 1. Menú móvil ----------
    var boton = document.getElementById('abrirMenu');
    var menu = document.getElementById('menu');
    var velo = document.getElementById('velo');
    function alternar(abrir) {
        if (!menu) return;
        menu.classList.toggle('abierto', abrir);
        if (velo) velo.hidden = !abrir;
        if (boton) boton.setAttribute('aria-expanded', String(abrir));
    }
    if (boton) boton.addEventListener('click', function () { alternar(!menu.classList.contains('abierto')); });
    if (velo) velo.addEventListener('click', function () { alternar(false); });

    // ---------- 2. Diálogo de confirmación ----------
    var dialogo = document.createElement('dialog');
    dialogo.className = 'alerta-ios';
    dialogo.innerHTML =
        '<p class="alerta-ios-titulo">¿Estás seguro?</p>' +
        '<p class="alerta-ios-texto"></p>' +
        '<div class="alerta-ios-botones">' +
        '  <button type="button" value="no" class="cancelar">Cancelar</button>' +
        '  <button type="button" value="si" class="destructivo">Confirmar</button>' +
        '</div>';
    document.body.appendChild(dialogo);
    var pendiente = null;
    dialogo.addEventListener('click', function (e) {
        var b = e.target.closest('button');
        if (!b) return;
        dialogo.close();
        if (b.value === 'si' && pendiente) { pendiente.dataset.confirmado = '1'; pendiente.requestSubmit(); }
        pendiente = null;
    });

    document.addEventListener('submit', function (e) {
        var form = e.target;
        // 2a. pedir confirmación
        if (form.dataset.confirmar && !form.dataset.confirmado) {
            e.preventDefault();
            pendiente = form;
            dialogo.querySelector('.alerta-ios-texto').textContent = form.dataset.confirmar;
            if (typeof dialogo.showModal === 'function') {
                dialogo.showModal();
                dialogo.querySelector('.cancelar').focus();
            } else if (window.confirm(form.dataset.confirmar)) {     // navegadores muy viejos
                form.dataset.confirmado = '1'; form.submit();
            }
            return;
        }
        // 4. evitar doble envío
        if (form.dataset.enviando) { e.preventDefault(); return; }
        form.dataset.enviando = '1';
        form.querySelectorAll('button[type=submit]').forEach(function (b) {
            b.disabled = true; b.dataset.texto = b.textContent; b.textContent = 'Procesando…';
        });
        setTimeout(function () {                                         // por si el navegador vuelve atrás
            delete form.dataset.enviando;
            form.querySelectorAll('button[type=submit]').forEach(function (b) {
                b.disabled = false; if (b.dataset.texto) b.textContent = b.dataset.texto;
            });
        }, 8000);
    });

    document.addEventListener('keydown', function (e) { if (e.key === 'Escape') alternar(false); });

    // ---------- 3. Toast para mensajes de éxito ----------
    document.querySelectorAll('.alerta.ok').forEach(function (a) {
        if (a.closest('.login-tarjeta')) return;
        a.classList.add('toast');
        a.setAttribute('role', 'status');
        a.setAttribute('aria-live', 'polite');
        setTimeout(function () { a.classList.add('saliendo'); }, 4500);
        setTimeout(function () { a.remove(); }, 5000);
    });

    // ---------- 5. PWA ----------
    if ('serviceWorker' in navigator) {
        window.addEventListener('load', function () {
            navigator.serviceWorker.register('/sw.js').catch(function () { /* sin PWA, la app sigue funcionando */ });
        });
    }
})();
