/// Every tuning knob of the sound modem lives here.
class Sonic {
  Sonic._();

  static const int sampleRate = 44100;

  /// Duration of one tone. Must be a multiple of 10. Raise to 60 or 80
  /// for noisy rooms (slower but more reliable).
  static const int symbolMs = 40;
  static const int hopMs = 10;
  static const int symbolSamples = sampleRate * symbolMs ~/ 1000;
  static const int hopSamples = sampleRate * hopMs ~/ 1000;
  static const int hopsPerSymbol = symbolMs ~/ hopMs;

  /// 16 tones = 4 bits per symbol.
  static const int toneCount = 16;
  static const double baseFreq = 2000;
  static const double toneSpacing = 100;
  static double toneFreq(int tone) => baseFreq + toneSpacing * tone;

  static const List<int> preamble = [0, 15, 0, 15, 0, 15, 0, 15];
  static const List<int> sync = [6, 9, 3, 12];
  static const List<int> head = [...preamble, ...sync];

  static const int payloadBytes = 32;
  static const int headerBytes = 4; // msgId, index, total, length
  static const int crcBytes = 2;
  static const int bodyBytes = headerBytes + payloadBytes + crcBytes;
  static const int bodySymbols = bodyBytes * 2;
  static const int frameSymbols = 12 + bodySymbols; // head (12) + body

  static const int gapMs = 200;

  /// Max size of one message after packing (about 1 KB).
  static const int maxMessageBytes = 1024;
}