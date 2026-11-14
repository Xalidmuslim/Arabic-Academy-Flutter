# Лингвистическая проверка словаря «Байна Ядейк» (три инструмента)

Интеграция добавлена **как отдельный Python-инструмент редактуры**, а не как Flutter-пакет.
Не изменяет `assets/data/*.json`, `lib/`, пользовательские данные, интерфейс, настройки, APK и Flutter-сборку.

## Данные

Читает `assets/data/corpus_manifest.json` и каждый перечисленный там JSON-файл с `entries[]`.
Читает также `assets/data/reviewed_articles_v1.json`, включая `definition[].ar`, `grammar[].ar`, `examples[].ar`, `important[].ar`, `synonyms[].ar`, `contrasts[].ar`.
Сохраняет идентификатор статьи и путь исходного файла в отчёте. Ничего не перезаписывает, не сводит разные значения в одну запись.

## Базовая проверка (без установки сторонних библиотек)

~~~sh
python3 -m unittest discover -s tools -p 'test_bayna_linguistic_audit.py' -v
python3 tools/bayna_linguistic_audit.py --repo . --output linguistic-audit.json
~~~

Опция `--limit 100` проверяет только первые 100 записей. По умолчанию проверяются все статьи и редакторские дополнения.
GitHub Actions «Bayna linguistic QA (read only)» запускает офлайн-проверку и сохраняет JSON-отчёт в артефактах CI.

## Опциональные анализаторы

1. **CAMeL Tools:** устанавливается в отдельном Python-окружении: `pip install camel-tools` и `camel_data -i light` (подходящий вариант моделей зависит от версии). Запуск: `--camel`. Выдаёт кандидатные морфологические разборы, не удостоверяет правильность и‘раба.
2. **Quranic Arabic Corpus:** скачайте неизменённый оригинал TSV 0.4 по https://corpus.quran.com/download/default.jsp , сохраняя лицензионные уведомления и атрибуцию. Запуск: `--quran-corpus /secure/path/quranic-corpus-morphology-0.4.txt`. Это справка по корню и морфологическим сегментам, не проверка значений каждого современного слова. Не включайте корпус в GitHub без учёта его условий.
3. **CamelParser:** отдельно подготовьте Python 3.11.13, исходники и модели по https://github.com/CAMeL-Lab/camel_parser . Запуск: `--parser-repo /secure/path/camel_parser --parser-python /secure/path/python3.11`. По умолчанию анализируются примеры первых 20 записей, не весь корпус, чтобы не запускать тысячи тяжёлых процессов.

Пример запуска **после** установки всех внешних компонентов:

~~~sh
python3 tools/bayna_linguistic_audit.py --repo . --output linguistic-audit-full.json \
  --camel --quran-corpus /secure/path/quranic-corpus-morphology-0.4.txt \
  --parser-repo /secure/path/camel_parser --parser-python /secure/path/python3.11 \
  --parser-max-entries 20
~~~

**Статус:** в GitHub Actions по умолчанию сторонние модели не устанавливаются. Все три движка в офлайн-отчёте обозначены `not_run`. Это **не** успешное тестирование реальных моделей; их нужно отдельно скачать и запустить.

## Критерии

- Никогда не исправлять тексты, огласовки, корни и ID автоматически.
- Пустые синонимы или антонимы не являются сами по себе ошибкой: нельзя придумывать отношения.
- Не добавлять русский текст в арабские словарные поля.
- Совпадение корня в кораническом корпусе не доказывает нужное чтение или значение.
- Спорные места проверять по исходному PDF и арабским словарям.
- Проверка работает вне APK, без замены Flutter-стека и без влияния на пользовательские данные.
