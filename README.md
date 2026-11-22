# Manual del servidor – Centro de Terapias Bienestar
Proyecto integrador – Sistemas Operativos
Autores: Katherine Restrepo Velez y Wilder Andres Rendon · Servidor: `server-kather` (Ubuntu en VirtualBox) · Acceso por SSH con usuario propio

> Todos los datos de pacientes son ficticios ("Paciente 001", etc.).

## 1. El caso
El Centro de Terapias Bienestar es un consultorio pequeño con una psicóloga, un fisioterapeuta y una recepcionista.
- **Información que no puede perderse:** historias clínicas y agenda de citas.
- **Necesidades:** cada profesional ve solo sus historias; recepción solo maneja citas; nadie externo accede; copia de seguridad automática.

## 2. Usuarios y grupos
| Usuario | Rol | Grupos | Justificación |
|---|---|---|---|
| katherine | Administradora | sudo | Única persona que administra el servidor |
| psicologa | Terapeuta | equipo, terapeutas | Necesita las citas y sus historias |
| fisio | Terapeuta | equipo, terapeutas | Necesita las citas y sus historias |
| recepcion | Recepción | equipo | Solo maneja la agenda, sin acceso clínico |
| invitado | Externo (prueba) | — | Demuestra que alguien externo no entra |

## 3. Carpetas y permisos
| Carpeta | Dueño:Grupo | Permiso | Acceso | Justificación |
|---|---|---|---|---|
| /srv/consultorio | root:equipo | 750 | Equipo | Nadie fuera del equipo accede |
| /srv/consultorio/citas | root:equipo | 2770 | Recepción y terapeutas | Agenda compartida; setgid para que los archivos nuevos queden del grupo equipo |
| /srv/consultorio/historias | root:terapeutas | 750 | Terapeutas | Recepción no ve información clínica |
| .../historias/psicologia | psicologa:psicologa | 700 | Psicóloga | Confidencialidad por profesional |
| .../historias/fisioterapia | fisio:fisio | 700 | Fisioterapeuta | Confidencialidad por profesional |

Para entrar a una carpeta se necesita permiso de ejecución (x) en todas las carpetas del camino; por eso recepción se detiene en `historias` y el invitado en `/srv/consultorio`.

**Pruebas realizadas** (`evidencias/02_pruebas_permisos.txt`):
| Prueba | Resultado |
|---|---|
| psicologa lee su historia | ✅ Entra |
| fisio intenta ver psicologia | ❌ Permiso denegado |
| recepcion ve citas | ✅ Entra |
| recepcion intenta ver historias | ❌ Permiso denegado |
| invitado intenta entrar a /srv/consultorio | ❌ Permiso denegado |

## 4. Servicio: consultorio-estado
- **Qué hace:** cada 60 segundos registra la fecha, el tiempo encendido, el uso de disco y el número de citas del día en `/var/log/consultorio/estado.log`. Sirve para saber si el servidor estuvo funcionando y cómo va la agenda.
- **Archivos:** `/usr/local/bin/consultorio-estado.sh` y `/etc/systemd/system/consultorio-estado.service` (copias en `scripts/`).
- **Configuración:** `Restart=always` (se recupera si se cae) y `enable` (arranca al encender la máquina).
- **Comandos útiles:**
  - Ver estado: `systemctl status consultorio-estado`
  - Ver registro: `sudo tail -f /var/log/consultorio/estado.log`
  - Reiniciar: `sudo systemctl restart consultorio-estado`
- **Prueba de recuperación:** se mató con `sudo systemctl kill -s KILL consultorio-estado` y volvió solo con otro PID (`evidencias/05_prueba_restart.txt`).

## 5. Respaldo
- **Script:** `/usr/local/bin/respaldo-consultorio.sh`. Crea `/backups/consultorio_FECHA_HORA.tar.gz` con `tar -czpf` (la `p` conserva los permisos).
- **Programación (cron de root):** todos los días a las 21:00 (`0 21 * * *`), al cierre del consultorio. Para pruebas y sustentación también cada 5 minutos (`*/5 * * * *`).
- **Protección:** `/backups` con permiso 700 y `umask 077`; solo root puede leer las copias, porque contienen historias clínicas.
- **Retención:** se borran automáticamente las copias de más de 7 días.
- **Cómo restaurar:**
  1. `ULTIMO=/backups/$(sudo ls -t /backups | head -1)`
  2. `sudo mkdir -p /tmp/restauracion`
  3. `sudo tar -xzpf "$ULTIMO" -C /tmp/restauracion`
  4. `sudo diff -r /srv/consultorio /tmp/restauracion/consultorio` (sin diferencias = copia completa)
  5. Si se perdió algo, copiarlo de /tmp/restauracion a /srv/consultorio.
- **Prueba realizada:** se restauró la copia creada por cron a las 12:40; 3 de 3 archivos, sin diferencias y con los permisos conservados (`evidencias/08_restauracion.txt`).

## 6. Seguridad
| Medida | Cómo se verifica | Riesgo que evita |
|---|---|---|
| Sin permisos 777 | `sudo find /srv /home /backups -perm -0777` | Que cualquier usuario lea, cambie o borre historias |
| sudo solo para katherine | `getent group sudo` y `sudo -l -U recepcion` | Que un empleado o una cuenta robada tome control del servidor |
| Sistema actualizado | `sudo apt update && sudo apt upgrade` | Que se aprovechen vulnerabilidades conocidas |
| Root sin login por SSH y cuenta bloqueada | `sudo sshd -T \| grep permitrootlogin` y `sudo passwd -S root` | Ataques de fuerza bruta contra root; cada acción queda a nombre de una persona |
| Historias en 700 y recepción fuera de terapeutas | `ls -l` | Fuga de información clínica |
| /backups en 700 y umask 077 | `sudo ls -l /backups` | Que la copia de seguridad se convierta en una fuga de datos |

Evidencia: `evidencias/09_seguridad.txt`

## 7. Qué hacer si algo falla
| Problema | Diagnóstico | Solución |
|---|---|---|
| El servicio no está activo | `systemctl status consultorio-estado` y `journalctl -u consultorio-estado -n 50` | Corregir el script, `sudo systemctl daemon-reload` y `sudo systemctl restart consultorio-estado` |
| No se crean respaldos | `systemctl status cron`, `sudo crontab -l`, `journalctl -u cron` | Iniciar cron, revisar la ruta del script y su permiso de ejecución |
| Disco lleno | `df -h`, `sudo du -sh /backups` | Borrar copias antiguas y revisar la retención |
| Un usuario no puede entrar a su carpeta | `id usuario`, `ls -l carpeta` | Agregarlo al grupo con `sudo usermod -aG grupo usuario` (debe volver a iniciar sesión) |
| Se borró un archivo | `sudo ls -lt /backups` | Restaurar desde /backups (sección 5) |
| No conecta por SSH | `systemctl status ssh` e `ip a` en la VM | Iniciar ssh, revisar si cambió la IP |
| `ls /backups/*.tar.gz` dice "No existe" con sudo | El `*` lo expande el usuario normal, que no puede leer /backups (700) | Usar `sudo ls /backups`; es señal de que la protección funciona |
| Las horas de los registros no coinciden | `date`, `timedatectl` | `sudo timedatectl set-timezone America/Bogota` |

## 8. Estructura del repositorio
- `README.md`: este manual
- `scripts/`: script del servicio, unidad systemd, script de respaldo y crontab
- `evidencias/`: salidas de las pruebas
- `capturas/`: capturas de pantalla
