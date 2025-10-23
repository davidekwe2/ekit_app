
class Lang {
  final String name;
  final String code;
  const Lang(this.name, this.code);
}

const List<Lang> kSpeechLangs = [
  // English
  Lang('English (US)', 'en-US'),
  Lang('English (UK)', 'en-GB'),
  Lang('English (Australia)', 'en-AU'),
  Lang('English (India)', 'en-IN'),
  Lang('English (Canada)', 'en-CA'),
  // French
  Lang('French (France)', 'fr-FR'),
  Lang('French (Canada)', 'fr-CA'),
  Lang('French (Belgium)', 'fr-BE'),
  Lang('French (Switzerland)', 'fr-CH'),
  // Spanish
  Lang('Spanish (Spain)', 'es-ES'),
  Lang('Spanish (US)', 'es-US'),
  Lang('Spanish (Mexico)', 'es-MX'),
  Lang('Spanish (Argentina)', 'es-AR'),
  // Portuguese
  Lang('Portuguese (Brazil)', 'pt-BR'),
  Lang('Portuguese (Portugal)', 'pt-PT'),
  // German, Italian, Dutch
  Lang('German', 'de-DE'),
  Lang('Italian', 'it-IT'),
  Lang('Dutch (Netherlands)', 'nl-NL'),
  Lang('Dutch (Belgium)', 'nl-BE'),
  // Russian, Arabic
  Lang('Russian', 'ru-RU'),
  Lang('Arabic (UAE)', 'ar-AE'),
  Lang('Arabic (Egypt)', 'ar-EG'),
  Lang('Arabic (Saudi Arabia)', 'ar-SA'),
  // Chinese + Cantonese
  Lang('Mandarin (Mainland)', 'cmn-Hans-CN'),
  Lang('Mandarin (Taiwan)', 'cmn-Hant-TW'),
  Lang('Cantonese (HK)', 'yue-Hant-HK'),
  // Japanese, Korean
  Lang('Japanese', 'ja-JP'),
  Lang('Korean', 'ko-KR'),
  // Hindi + Bengali
  Lang('Hindi', 'hi-IN'),
  Lang('Bengali (Bangladesh)', 'bn-BD'),
  Lang('Bengali (India)', 'bn-IN'),
  // Nordics
  Lang('Swedish', 'sv-SE'),
  Lang('Norwegian Bokmål', 'nb-NO'),
  Lang('Danish', 'da-DK'),
  Lang('Finnish', 'fi-FI'),
  // CEE
  Lang('Greek', 'el-GR'),
  Lang('Czech', 'cs-CZ'),
  Lang('Hungarian', 'hu-HU'),
  Lang('Polish', 'pl-PL'),
  Lang('Romanian', 'ro-RO'),
  // SE Asia
  Lang('Thai', 'th-TH'),
  Lang('Vietnamese', 'vi-VN'),
  Lang('Indonesian', 'id-ID'),
  Lang('Malay', 'ms-MY'),
  // Others
  Lang('Hebrew', 'he-IL'),
  Lang('Ukrainian', 'uk-UA'),
  Lang('Catalan', 'ca-ES'),
  Lang('Slovak', 'sk-SK'),
  Lang('Slovenian', 'sl-SI'),
  Lang('Croatian', 'hr-HR'),
  Lang('Serbian', 'sr-RS'),
];
