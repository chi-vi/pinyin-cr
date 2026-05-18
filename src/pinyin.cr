require "./lib_glib"
require "./lib_pinyin"

module Pinyin
  VERSION = "0.1.0"

  class PinyinError < Exception; end

  # Configure system and user directories as module-level properties.
  # These can be accessed and mutated globally:
  # `Pinyin.user_dir = "/crux/confs"`
  class_property system_dir : String = "/usr/lib/x86_64-linux-gnu/libpinyin/data"
  class_property user_dir : String = File.join(ENV["HOME"]? || "/tmp", ".local", "share", "pinyin-cr")

  # Tone mark tables indexed by tone number (1–4). Index 0 is unused.
  # Neutral tone (5) uses the bare vowel with no diacritic.
  TONE_MARKS = {
    'a' => ['\0', 'ā', 'á', 'ǎ', 'à'],
    'e' => ['\0', 'ē', 'é', 'ě', 'è'],
    'i' => ['\0', 'ī', 'í', 'ǐ', 'ì'],
    'o' => ['\0', 'ō', 'ó', 'ǒ', 'ò'],
    'u' => ['\0', 'ū', 'ú', 'ǔ', 'ù'],
    'v' => ['\0', 'ǖ', 'ǘ', 'ǚ', 'ǜ'], # libpinyin uses 'v' for ü/u-umlaut
  }

  # Raw tone data embedded at compile time — no runtime file I/O.
  # Format per line: "char\tsyl:tone,syl:tone,..."
  # Syllable uses 'v' for ü (matching libpinyin's output). Tones: 1–4, 5=neutral.
  TONE_DATA = {{read_file("#{__DIR__}/pinyin_tones.txt")}}

  # Lazily built lookup: codepoint → "syl:tone,syl:tone,..."
  @@tone_table : Hash(UInt32, String)? = nil

  protected def self.tone_table : Hash(UInt32, String)
    @@tone_table ||= begin
      table = Hash(UInt32, String).new(initial_capacity: 27000)
      TONE_DATA.each_line(chomp: true) do |line|
        tab = line.index('\t') || next
        char_cp = line[0].ord.to_u32
        entry = line[tab + 1..]
        table[char_cp] = entry unless entry.empty?
      end
      table
    end
  end

  # Converts a syllable+tone-number string (e.g. "bei3", "lv4", "xue2") into a
  # tone-marked pinyin string (e.g. "běi", "lǜ", "xué").
  #
  # Tone placement rules (standard Mandarin):
  #   1. If the syllable has 'a' or 'e', the mark always goes there.
  #   2. If the syllable has 'ou', the mark goes on 'o'.
  #   3. Otherwise, the mark goes on the last vowel.
  protected def self.apply_tone_mark(syllable : String, tone : Int32) : String
    return syllable.gsub('v', 'ü') if tone == 5 || tone == 0

    vowels = {'a', 'e', 'i', 'o', 'u', 'v'}

    # Rule 1: 'a' or 'e' always takes the mark
    {'a', 'e'}.each do |vowel|
      if (idx = syllable.index(vowel))
        marked = TONE_MARKS[vowel][tone].to_s
        result = syllable[0...idx] + marked + syllable[idx + 1..]
        return result.gsub('v', 'ü')
      end
    end

    # Rule 2: 'ou' → mark 'o'
    if (idx = syllable.index("ou"))
      marked = TONE_MARKS['o'][tone].to_s
      return syllable[0...idx] + marked + syllable[idx + 1..].gsub('v', 'ü')
    end

    # Rule 3: mark the last vowel
    last_vowel_idx = -1
    syllable.each_char.with_index do |c, i|
      last_vowel_idx = i if vowels.includes?(c)
    end

    if last_vowel_idx >= 0
      vowel = syllable[last_vowel_idx]
      marked = TONE_MARKS[vowel]? ? TONE_MARKS[vowel][tone].to_s : vowel.to_s
      result = syllable[0...last_vowel_idx] + marked + syllable[last_vowel_idx + 1..]
      return result.gsub('v', 'ü')
    end

    syllable.gsub('v', 'ü')
  end

  # Looks up the tone-marked pinyin for a character given its syllable
  # (as returned by libpinyin, e.g. "bei" for 北).
  # For polyphones, the syllable is used to pick the correct pronunciation.
  protected def self.toned_pinyin(char : String, syllable : String) : String
    cp = char.chars.first?.try(&.ord.to_u32) || return syllable
    entry = tone_table[cp]? || return syllable

    # Entry is "syl:tone,syl:tone,..." — find the matching syllable
    entry.split(',') do |part|
      colon = part.index(':') || next
      syl = part[0...colon]
      next unless syl == syllable
      tone = part[colon + 1]?.try(&.to_i) || next
      return apply_tone_mark(syllable, tone)
    end

    # Fallback: use the first entry regardless of syllable match
    first = entry.split(',', 2).first
    if (colon = first.index(':'))
      syl = first[0...colon]
      tone = first[colon + 1]?.try(&.to_i) || 5
      apply_tone_mark(syl, tone)
    else
      syllable
    end
  end

  # Helper to identify Chinese characters (CJK Unified Ideographs).
  def self.chinese_char?(char : Char) : Bool
    char.ord >= 0x4E00 && char.ord <= 0x9FFF
  end

  # Represents a segmented unit of text with its Pinyin translation.
  # If a segmented unit does not have a Pinyin translation (e.g., punctuation or English),
  # the `pinyin` field will contain the original `text` itself.
  struct Element
    getter text : String
    getter pinyin : String

    def initialize(@text : String, @pinyin : String)
    end
  end

  # Converts Chinese text into a formatted Pinyin string.
  #
  # ```
  # Pinyin.to_pinyin("北京大学")       # => "běi jīng dà xué"
  # Pinyin.to_pinyin("你好, World!") # => "nǐ hǎo , World!"
  # ```
  def self.to_pinyin(zh_text : String, separator : String = " ", system_dir : String = @@system_dir, user_dir : String = @@user_dir) : String
    to_pinyin_array(zh_text, system_dir, user_dir).join(separator, &.pinyin)
  end

  # Converts Chinese text into an array of Pinyin elements.
  # This matches original characters to their individual Pinyin outputs,
  # making it perfect for rendering `<ruby>` / `<rt>` HTML tags.
  #
  # ```
  # elements = Pinyin.to_pinyin_array("北京大学")
  # # => [
  # #      Pinyin::Element(@text="北", @pinyin="běi"),
  # #      Pinyin::Element(@text="京", @pinyin="jīng"),
  # #      Pinyin::Element(@text="大", @pinyin="dà"),
  # #      Pinyin::Element(@text="学", @pinyin="xué")
  # #    ]
  # ```
  def self.to_pinyin_array(zh_text : String, system_dir : String = @@system_dir, user_dir : String = @@user_dir) : Array(Element)
    # Ensure user directory exists
    Dir.mkdir_p(user_dir) unless Dir.exists?(user_dir)

    # Ensure user.conf exists to prevent libpinyin from printing "open ... failed." to stderr
    user_conf_path = File.join(user_dir, "user.conf")
    File.write(user_conf_path, "") unless File.exists?(user_conf_path)

    context = LibPinyin.pinyin_init(system_dir, user_dir)
    raise PinyinError.new("Failed to initialize libpinyin context with system_dir: #{system_dir}") if context.nil?

    begin
      instance = LibPinyin.pinyin_alloc_instance(context)
      raise PinyinError.new("Failed to allocate libpinyin instance") if instance.nil?

      begin
        pinyin_results = [] of Element

        zh_text.chars.chunk { |c| chinese_char?(c) }.each do |is_chinese, chars|
          chunk_str = chars.join
          if is_chinese
            pinyin_results.concat(get_pinyin_elements(instance, chunk_str))
          else
            pinyin_results << Element.new(chunk_str, chunk_str)
          end
        end

        return pinyin_results
      ensure
        LibPinyin.pinyin_free_instance(instance)
      end
    ensure
      LibPinyin.pinyin_fini(context)
    end
  end

  # Internal helper to convert a block of purely Chinese characters to Pinyin elements.
  private def self.get_pinyin_elements(instance : LibPinyin::PinyinInstanceT, han_text : String) : Array(Element)
    # First attempt: segment the entire block
    LibPinyin.pinyin_reset(instance)
    return extract_pinyin_elements_from_instance(instance) if LibPinyin.pinyin_phrase_segment(instance, han_text)

    # Fallback: process character by character if the full phrase segmentation fails (e.g. rare characters)
    pinyins = [] of Element
    han_text.each_char do |char|
      LibPinyin.pinyin_reset(instance)
      if LibPinyin.pinyin_phrase_segment(instance, char.to_s)
        pinyins.concat(extract_pinyin_elements_from_instance(instance))
      else
        pinyins << Element.new(char.to_s, char.to_s)
      end
    end
    pinyins
  end

  # Internal helper to extract Pinyin elements from a segmented instance.
  private def self.extract_pinyin_elements_from_instance(instance : LibPinyin::PinyinInstanceT) : Array(Element)
    results = [] of Element
    phrase_str_ptr = Pointer(LibC::Char).null

    unless LibPinyin.pinyin_get_n_phrase(instance, out num_phrases)
      return results
    end

    (0...num_phrases).each do |i|
      next unless LibPinyin.pinyin_get_phrase_token(instance, i, out token)
      next if token == 0 # null_token

      # Get the original phrase characters
      phrase_str = ""
      if LibPinyin.pinyin_token_get_phrase(instance, token, nil, pointerof(phrase_str_ptr))
        phrase_str = String.new(phrase_str_ptr)
        LibGLib.g_free(phrase_str_ptr.as(Void*))
      end

      next if phrase_str.empty?

      fallback = -> { phrase_str.each_char { |c| results << Element.new(c.to_s, c.to_s) } }

      # Check if the token has any pronunciation
      unless LibPinyin.pinyin_token_get_n_pronunciation(instance, token, out num_pron) && num_pron > 0
        fallback.call
        next
      end

      keys_array = LibGLib.g_array_new(0, 0, 2)
      begin
        unless LibPinyin.pinyin_token_get_nth_pronunciation(instance, token, 0, keys_array)
          fallback.call
          next
        end

        garray = keys_array.value
        chewing_keys = garray.data.as(UInt16*)
        chars = phrase_str.chars

        (0...garray.len).each do |k|
          key_ptr = chewing_keys + k
          char_str = chars[k]?.try(&.to_s) || ""

          if LibPinyin.pinyin_get_pinyin_string(instance, key_ptr, out pinyin_str_ptr)
            syllable = String.new(pinyin_str_ptr)
            LibGLib.g_free(pinyin_str_ptr.as(Void*))
            # syllable is toneless (e.g. "bei") — look up the tone and apply the mark
            results << Element.new(char_str, toned_pinyin(char_str, syllable))
          else
            results << Element.new(char_str, char_str)
          end
        end
      ensure
        LibGLib.g_array_free(keys_array, 1)
      end
    end

    results
  end
end
