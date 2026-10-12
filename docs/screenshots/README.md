# Screenshot evidence

`flutter-tester/` contains **actual Flutter widget tester engine renders** with
bundled product fonts, artwork and content. These are **not Android/device
screenshots**. See [visual-validation.md](../visual-validation.md) for coverage,
commands and limitations. `flutter-tester/latest.json` points to the latest run;
only its `complete_matrix_passed: true` run qualifies as passing layout evidence.
Failed runs remain clearly diagnostic, with case JSONs and raw Flutter logs.

The emulator ANR image `android-debug-first.png` was removed from acceptance.
No image compositing, reference crops or substituted UI is used.
