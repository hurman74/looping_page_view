## 0.1.0

- Initial release: `LoopingPageView` (`.builder` and a `children` constructor) and
  `LoopingPageController`, whose pages are item indexes.
- `animateToPage` takes the shortest way round, or a `LoopDirection`; `nextPage` and
  `previousPage` wrap around.
- `loop` can be turned off and on at runtime, and `itemCount` can change, without the item on
  screen changing.
