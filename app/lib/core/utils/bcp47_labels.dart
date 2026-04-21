/// Static BCP-47 tag → display-label map. Adding a language here surfaces it
/// in designer + learner pickers; removing it doesn't purge existing uploads
/// but will render the label as the raw code.
const Map<String, String> kBcp47Labels = <String, String>{
  'en': 'English',
  'zh-CN': '简体中文',
  'zh-Hant': '繁體中文',
  'ja': '日本語',
  'ko': '한국어',
  'es': 'Español',
  'fr': 'Français',
  'de': 'Deutsch',
  'pt-BR': 'Português (Brasil)',
  'ru': 'Русский',
  'it': 'Italiano',
  'nl': 'Nederlands',
  'ar': 'العربية',
  'he': 'עברית',
  'fa': 'فارسی',
  'hi': 'हिन्दी',
  'tr': 'Türkçe',
  'pl': 'Polski',
  'id': 'Bahasa Indonesia',
  'vi': 'Tiếng Việt',
};

/// Sorted language codes for picker UIs.
final List<String> kSupportedCaptionLanguages =
    kBcp47Labels.keys.toList()..sort();

/// Renders a display label for a BCP-47 code; falls back to the raw code when
/// it isn't in the label map.
String captionLanguageLabel(String code) => kBcp47Labels[code] ?? code;

/// Primary-language tags that are written right-to-left.
const Set<String> kRtlCaptionPrimaryLanguages = <String>{'ar', 'he', 'fa', 'ur'};

/// Returns true when caption text for [code] should render right-to-left.
/// Matches on the primary subtag only (e.g. `ar-SA` is RTL because `ar` is).
bool isRtlCaptionLanguage(String code) {
  final primary = code.split('-').first;
  return kRtlCaptionPrimaryLanguages.contains(primary);
}
