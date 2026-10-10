import '../../pdf_text_extractor.dart';

class PdfColumnBoundaries {
  static const _maxHeaderLabelGap = 20;

  final List<_Occurrence> _occurrences;

  const PdfColumnBoundaries._(this._occurrences);

  factory PdfColumnBoundaries.detect(
    List<PdfPageLayout> pages, {
    required String leftLabel,
    required String rightLabel,
  }) {
    final occurrences = <_Occurrence>[];
    for (var pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      final page = pages[pageIndex];
      var cursor = 0;
      while (true) {
        final leftIdx = page.text.indexOf(leftLabel, cursor);
        if (leftIdx < 0) break;
        final afterLeft = leftIdx + leftLabel.length;
        final rightIdx = page.text.indexOf(rightLabel, afterLeft);
        if (rightIdx < 0) break;
        if (rightIdx - afterLeft > _maxHeaderLabelGap) {
          cursor = afterLeft;
          continue;
        }
        final leftX = _centerX(page, leftIdx, afterLeft);
        final rightX = _centerX(page, rightIdx, rightIdx + rightLabel.length);
        if (leftX != null && rightX != null) {
          occurrences.add(
            _Occurrence(
              pageIndex: pageIndex,
              offset: leftIdx,
              boundaryX: (leftX + rightX) / 2,
            ),
          );
        }
        cursor = rightIdx + rightLabel.length;
      }
    }
    return PdfColumnBoundaries._(occurrences);
  }

  double? boundaryXForPosition(int pageIndex, int offset) {
    if (_occurrences.isEmpty) return null;
    const perPageKeySpan = 1000000;
    final target = pageIndex * perPageKeySpan + offset;

    _Occurrence? nearestPreceding;
    int? nearestPrecedingDistance;
    _Occurrence? nearestFollowing;
    int? nearestFollowingDistance;
    for (final occurrence in _occurrences) {
      final key = occurrence.pageIndex * perPageKeySpan + occurrence.offset;
      final distance = key - target;
      if (distance <= 0) {
        final absDistance = -distance;
        if (nearestPrecedingDistance == null ||
            absDistance < nearestPrecedingDistance) {
          nearestPrecedingDistance = absDistance;
          nearestPreceding = occurrence;
        }
      } else {
        if (nearestFollowingDistance == null ||
            distance < nearestFollowingDistance) {
          nearestFollowingDistance = distance;
          nearestFollowing = occurrence;
        }
      }
    }
    return (nearestPreceding ?? nearestFollowing)?.boundaryX;
  }
}

class _Occurrence {
  final int pageIndex;
  final int offset;
  final double boundaryX;
  const _Occurrence({
    required this.pageIndex,
    required this.offset,
    required this.boundaryX,
  });
}

double? _centerX(PdfPageLayout page, int start, int end) {
  if (start < 0 || end <= start || end > page.charRects.length) return null;
  final rects = page.charRects.sublist(start, end);
  final left = rects.map((r) => r.left).reduce((a, b) => a < b ? a : b);
  final right = rects.map((r) => r.right).reduce((a, b) => a > b ? a : b);
  return (left + right) / 2;
}

bool? isRightOfColumn(
  PdfPageLayout page,
  int start,
  int end,
  double boundaryX,
) {
  final center = _centerX(page, start, end);
  if (center == null) return null;
  return center > boundaryX;
}

const _maxPlausibleInterCharGapPoints = 20.0;

(int, int) trimAmountRange(PdfPageLayout page, int start, int end) {
  if (start < 0 || end <= start || end > page.charRects.length) {
    return (start, end);
  }
  var cut = start;
  for (var i = start + 1; i < end; i++) {
    final gap = page.charRects[i].left - page.charRects[i - 1].right;
    if (gap > _maxPlausibleInterCharGapPoints) cut = i;
  }
  return (cut, end);
}

(int, int, String) trimmedAmountText(PdfPageLayout page, int start, int end) {
  final (trimmedStart, trimmedEnd) = trimAmountRange(page, start, end);
  return (
    trimmedStart,
    trimmedEnd,
    page.text.substring(trimmedStart, trimmedEnd),
  );
}
