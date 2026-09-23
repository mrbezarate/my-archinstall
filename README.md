# 🚀 ASUS ROG Strix G16 (G614JV) - Arch Linux Setup

Автоматический скрипт полной настройки Arch Linux для **ASUS ROG Strix G16 (2023-2024)**:
* **NVIDIA GeForce RTX 4060 Mobile** + Wayland + 240Hz (DRM modesetting, Power management).
* **KVM + QEMU + Virt-Manager** для запуска виртуалок Debian (Клиент, Сервер, Роутер, DNS) с виртуальными свичами (`create-vswitch`) и Wireshark без root.
* **Niri** (Scrollable Tiling Compositor на Rust) + окружение из [traits-arch/configs](https://github.com/traits-arch/configs.git):
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