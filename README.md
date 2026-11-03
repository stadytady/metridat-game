# Metridat

Головоломка на сетке (Godot 4.5, GDScript). На каждой плитке нарисован узор. Нажатие сдвигает на один шаг цвет всех клеток под узором (по кругу из `k` цветов). Цель — сделать тёмным всё поле.

| Узор | Что меняет |
|---|---|
| `PLUS` | себя и 4 соседа по сторонам |
| `CROSS` | себя и 4 соседа по диагонали |
| `RING` | 8 соседей, **без себя** |
| `ROW` / `COL` | всю строку / весь столбец |

Нажатия коммутируют, поэтому задача — это линейная система над `Z_p`, где `p` = число цветов, простое. `Solver` решает её методом Гаусса и перебирает ядро (до 4096 вариантов), так что «минимум» на экране — честный оптимум. `Generator` перемешивает решённое поле случайными нажатиями, поэтому каждый уровень решаем. Уровни детерминированы: seed — от номера уровня.

Управление: клик или тап по плитке. `Z`/`Backspace` — отменить, `R` — заново, `N`/`Enter`/`→` — следующий уровень, `P`/`←` — предыдущий.

## Структура

```
project.godot, export_presets.cfg   проект и пресеты Web (без потоков) и Linux x86_64
scenes/main.tscn                    единственная сцена; UI собирается в коде
src/core/                           правила, без нод и рендера
  board.gd       поле, узоры, press/unpress
  solver.gd      минимальное решение над Z_p
  generator.gd   уровень из spec + seed, par = минимум решателя
  levels.gd      таблица уровней и процедурное продолжение
  progress.gd    открытые уровни и рекорды (user://progress.cfg)
src/ui/                             main.gd (экран), board_view.gd (отрисовка и ввод), palette.gd
tests/                              test_*.gd и раннер run_tests.gd
tools/                              install-godot.sh, test.sh, export.sh
```

## Команды

```sh
GODOT_VERSION=4.5.1 tools/install-godot.sh              # godot в ~/.local/bin, проверка SHA-512
GODOT_VERSION=4.5.1 tools/install-godot.sh --templates  # + шаблоны Web/Linux (качается .tpz на 1.3 ГБ)
tools/test.sh                                           # unit-тесты + smoke-запуск main.tscn
tools/export.sh Web Linux                               # build/web, build/linux
python3 -m http.server -d build/web 8000                # открыть Web-сборку локально
```

Если `godot` не в `PATH`, задайте `GODOT=/path/to/godot`.

## CI и публикация

`.github/workflows/ci.yml`: тесты → экспорт Web и Linux → деплой Web на GitHub Pages (только push в `main`). Linux-бинарь лежит в артефактах прогона.

Pages нужно один раз включить вручную: **Settings → Pages → Source: GitHub Actions**. Иначе job `pages` упадёт.

Web-экспорт собран без потоков (`variant/thread_support=false`): GitHub Pages не отдаёт COOP/COEP, без них `SharedArrayBuffer` недоступен. `.wasm` движка весит около 38 МБ, первая загрузка заметна.

## Статус проверки

| Что | Где проверено |
|---|---|
| unit-тесты (16), smoke main.tscn | локально, Godot 4.5.1 headless |
| экспорт Web и Linux | локально |
| Web-сборка открывается, клик меняет поле | локально, headless Chromium (WebGL2 через SwiftShader) |
| CI и Pages | не проверено до первого прогона в Actions |
