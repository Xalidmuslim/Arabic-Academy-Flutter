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
2. **Quranic Arabic Corpus:** уже интегрирован в автоматический GitHub Actions `Bayna linguistic QA (read only)`. Рабочий файл версии 0.4, предоставленный пользователем, проверен: 6 309 503 байта, 128 219 сегментов; SHA-256 `a1d12923815341face765083805d2148ed2d9f5cc3f7d6665219d887675d8c46`, git blob SHA `b91cec6e95d5e0306550b4aedacc7380dc71152a`. Он побайтово совпадает с копией в GitHub `cltk/arabic_morphology_quranic-corpus` (закреплённый коммит `b5abd4d8fadd775f3329f34cbe10531fac71e391`). В CI файл скачивается во временный каталог, проверяется контрольной суммой и не изменяется. Исходный файл **не** добавляется в репозиторий и не публикуется среди артефактов. В публичный JSON-отчёт входят **только координаты** совпадений `location` и их тип, а не морфологические аннотации. Источники и атрибуция: [Quranic Arabic Corpus](https://corpus.quran.com/), © 2011 Kais Dukes, лицензия GPL; встроенный текст Tanzil © 2008–2009 Tanzil.info, CC BY-ND 3.0. Для локального запуска используйте `--quran-corpus /secure/path/quranic-corpus-morphology-0.4.txt`. Корпус служит справкой и не удостоверяет огласовки каждого слова словаря.
3. **CamelParser:** отдельно подготовьте Python 3.11.13, исходники и модели по https://github.com/CAMeL-Lab/camel_parser . Запуск: `--parser-repo /secure/path/camel_parser --parser-python /secure/path/python3.11`. По умолчанию анализируются примеры первых 20 записей, не весь корпус, чтобы не запускать тысячи тяжёлых процессов.

Пример запуска **после** установки всех внешних компонентов:

~~~sh
python3 tools/bayna_linguistic_audit.py --repo . --output linguistic-audit-full.json \
  --camel --quran-corpus /secure/path/quranic-corpus-morphology-0.4.txt \
  --parser-repo /secure/path/camel_parser --parser-python /secure/path/python3.11 \
  --parser-max-entries 20
~~~

**Статус:** Quranic Arabic Corpus **уже включён и проверен** в GitHub Actions. Отдельные модели **CAMeL Tools** и **CamelParser** в этом workflow не устанавливаются и в отчёте отмечены `not_run`. Работа трёх движков одновременно не заявляется, пока не выполнены их реальные интеграционные тесты.

## Критерии

- Никогда не исправлять тексты, огласовки, корни и ID автоматически.
- Пустые синонимы или антонимы не являются сами по себе ошибкой: нельзя придумывать отношения.
- Не добавлять русский текст в арабские словарные поля.
- Совпадение корня в кораническом корпусе не доказывает нужное чтение или значение.
- Спорные места проверять по исходному PDF и арабским словарям.
- Проверка работает вне APK, без замены Flutter-стека и без влияния на пользовательские данные.
