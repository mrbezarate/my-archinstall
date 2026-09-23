# 🚀 ASUS ROG Strix G16 (G614JV) - Arch Linux Setup

Автоматический скрипт полной настройки Arch Linux для **ASUS ROG Strix G16 (2023-2024)**:
* **NVIDIA GeForce RTX 4060 Mobile** + Wayland + 240Hz (DRM modesetting, Power management).
* **KVM + QEMU + Virt-Manager** для запуска виртуалок Debian (Клиент, Сервер, Роутер, DNS) с виртуальными свичами (`create-vswitch`) и Wireshark без root.
* **Niri** (Scrollable Tiling Compositor на Rust) + окружение из включёнными конфигами:
  * **Waybar** (стильная статусная панель)
  * **SwayNC** (центр уведомлений Nova-Dark)
  * **Rofi** (меню приложений и красивый powermenu)
  * **Alacritty** + **Starship**
  * **SDDM** (вход в систему)
  * Исправление путей (`/home/xal` -> актуальный домашний каталог) и обои.

---

## ⚡ Быстрый запуск в Arch Linux

В консоли Arch Linux введи всего 4 команды:

```bash
git clone https://github.com/mrbezarate/my-archinstall.git
cd my-archinstall
chmod +x install.sh
./install.sh
```

*(Скрипт сам запросит `sudo`, установит драйверы, виртуализацию, Niri, накатит конфиги и предложит перезагрузиться)*.

---

## ⌨️ Основные горячие клавиши (Niri)

* `Super` = Клавиша Windows
* `Super + Enter` — Терминал Alacritty
* `Super + D` — Меню всех приложений (Rofi)
* `Super + E` — Меню выключения / перезагрузки
* `Super + Q` — Закрыть окно
* `Super + F` — Развернуть колонку на весь экран
* `Super + H / L` или свайп тремя пальцами по тачпаду — Плавная прокрутка бесконечной ленты окон
* `Super + 1..9` — Переключение рабочих столов

---

## 🌐 Сетевая лаборатория (4 виртуалки Debian)

1. Запуск GUI виртуалок:
   ```bash
   virt-manager
   ```
2. Создание изолированного виртуального свича для связи Клиент <-> Роутер:
   ```bash
   sudo create-vswitch br-lan1
   sudo create-vswitch br-lan2
   ```
3. Захват пакетов в Wireshark без пароля root:
   ```bash
   wireshark
   ```

## Notes for current Arch Linux

The installer performs a full `pacman -Syu` before installing the desktop stack, enables `multilib` before installing 32-bit NVIDIA userspace, does not silently ignore pacman failures, writes an install log to `/var/log/my-archinstall/install.log`, and runs a verification pass at the end.

The 2026 cleanup also removes obsolete X11/MPD helpers from the Wayland configuration, switches audio controls to PipeWire/WirePlumber (`wpctl`), uses Niri's native screenshot actions, removes the stale second-battery entry, fixes hard-coded `/home/xal` paths at install time, and installs every utility directly referenced by the shipped configs.

NVIDIA is installed using `nvidia-open-dkms`; the old `nvidia-dkms` package is no longer present in current Arch repositories. The UI uses the current `rofi` package rather than the standalone `rofi-wayland` package. ASUS utilities are taken from the ASUS Linux/OGC repository.

`supergfxctl` is optional because ASUS Linux currently marks it as being phased out; set `INSTALL_SUPERGFXCTL=1` before running the installer only when you specifically need it (for example, VFIO experiments).
