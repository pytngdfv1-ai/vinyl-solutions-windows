# VinylSolutions para Windows

Biblioteca virtual de discos de vinilo (cajón de madera 3D, tocadisco, Koofr y carpeta local). Mismo código `lib/` que la app de Android.

## Descargar e instalar

1. Ve a **[Releases](../../releases/latest)**.
2. Descarga **`VinylSolutions-Setup.exe`** y ejecútalo (instala solo para tu usuario, con acceso directo y desinstalador).
3. Si Windows muestra **«Windows protegió su PC»** (SmartScreen): toca **Más información → Ejecutar de todas formas**. Aparece porque el instalador no tiene certificado de firma de código (ver abajo).

Alternativa sin instalar: descarga `VinylSolutions-portable.zip`, descomprímelo y abre `vinyl_solutions.exe`.

## Actualizaciones automáticas

La app busca versiones nuevas al abrir y cada 6 horas. Si hay una, ofrece instalarla sin desinstalar nada. Solo descargas el Setup **una vez**.

## Atajos

| Tecla | Acción |
|---|---|
| Espacio | Play / pausa |
| ← / → | Tema anterior / siguiente |
| Esc | Volver |
| Rueda del ratón | Hojear el cajón |
| Clic derecho o mantener pulsado | Borrar disco |

## Publicar una versión nueva (para el dueño del repo)

```bash
git tag v1.0.1
git push origin v1.0.1
```

El workflow `build-windows.yml` compila, crea el instalador y el ZIP, firma el appcast y publica todo en Releases. La versión sale de la etiqueta y debe ser siempre mayor que la anterior. También se puede lanzar a mano (Actions → Build Windows → Run workflow) para una compilación de prueba.

## Claves de actualización (una sola vez)

Las actualizaciones se firman con una clave DSA (WinSparkle). La **privada** va en Secrets (nunca en el código); la **pública** se sube al repo.

1. Instala [Git for Windows](https://git-scm.com/download/win) (trae `openssl`) y abre **Git Bash** en una carpeta vacía.
2. Ejecuta:
   ```bash
   openssl dsaparam -out dsaparam.pem 1024
   openssl gendsa -out dsa_priv.pem dsaparam.pem
   openssl dsa -in dsa_priv.pem -pubout -out dsa_pub.pem
   ```
3. Sube **solo** `dsa_pub.pem` a la raíz del repo (`pytngdfv1-ai/vinyl-solutions-windows`).
4. En GitHub: **Settings → Secrets and variables → Actions → New repository secret**. Nombre: `DSA_PRIV_PEM`. Valor: todo el contenido de `dsa_priv.pem`.
5. **Guarda `dsa_priv.pem` en un lugar seguro y bórralo de la carpeta de trabajo.** Si lo pierdes, las apps ya instaladas no podrán recibir actualizaciones.

## Aviso de SmartScreen

Sin certificado de firma de código, Windows SmartScreen avisa al ejecutar el instalador. Es normal y no indica un virus. Para quitarlo:

- Comprar un certificado de firma de código (OV o EV) o usar Azure Trusted Signing, y firmar `.exe` e instalador en el workflow.
- Un certificado EV elimina el aviso de inmediato; OV y el reconocimiento por descargas lo quitan con el tiempo.

## Desarrollo

Flutter 3.24.x. El destino Windows (`windows/`) se genera con `flutter create --platforms=windows .` si falta (el CI lo hace solo).

```bash
flutter pub get
flutter run -d windows
```
