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

  # Represents a segmented unit of text with its Pinyin translation.
  # If a segmented unit does not have a Pinyin translation (e.g., punctuation or English),
  # the `pinyin` field will contain the original `text` itself.
  struct Element
    getter text : String
    getter pinyin : String

    def initialize(@text : String, @pinyin : String)
    end
  end

  # Helper to identify Chinese characters (CJK Unified Ideographs).
  def self.chinese_char?(char : Char) : Bool
    char.ord >= 0x4E00 && char.ord <= 0x9FFF
  end

  # Converts Chinese text into a formatted Pinyin string.
  #
  # ```
  # Pinyin.to_pinyin("北京大学") # => "bei jing da xue"
  # Pinyin.to_pinyin("你好, World!") # => "ni hao , World!"
  # ```
  def self.to_pinyin(zh_text : String, separator : String = " ", system_dir : String = @@system_dir, user_dir : String = @@user_dir) : String
    elements = to_pinyin_array(zh_text, system_dir, user_dir)
    pinyin_results = [] of String
    
    elements.each do |element|
      pinyin_results << element.pinyin
    end
    
    joined = pinyin_results.join(separator)
    if separator == " "
      joined = joined.gsub(/\s+/, " ").strip
    end
    joined
  end

  # Converts Chinese text into an array of Pinyin elements.
  # This matches original characters to their individual Pinyin outputs,
  # making it perfect for rendering `<ruby>` / `<rt>` HTML tags.
  #
  # ```
  # elements = Pinyin.to_pinyin_array("北京大学")
  # # => [
  # #      Pinyin::Element(@text="北", @pinyin="bei"),
  # #      Pinyin::Element(@text="京", @pinyin="jing"),
  # #      Pinyin::Element(@text="大", @pinyin="da"),
  # #      Pinyin::Element(@text="学", @pinyin="xue")
  # #    ]
  # ```
  def self.to_pinyin_array(zh_text : String, system_dir : String = @@system_dir, user_dir : String = @@user_dir) : Array(Element)
    # Ensure user directory exists
    Dir.mkdir_p(user_dir) unless Dir.exists?(user_dir)

    # Ensure user.conf exists to prevent libpinyin from printing "open ... failed." to stderr
    user_conf_path = File.join(user_dir, "user.conf")
    unless File.exists?(user_conf_path)
      File.write(user_conf_path, "")
    end

    context = LibPinyin.pinyin_init(system_dir, user_dir)
    if context.nil?
      raise PinyinError.new("Failed to initialize libpinyin context with system_dir: #{system_dir}")
    end

    begin
      instance = LibPinyin.pinyin_alloc_instance(context)
      if instance.nil?
        raise PinyinError.new("Failed to allocate libpinyin instance")
      end

      begin
        pinyin_results = [] of Element
        current_chunk = [] of Char
        is_chinese = false

        zh_text.each_char do |char|
          char_is_chinese = chinese_char?(char)
          if current_chunk.empty?
            is_chinese = char_is_chinese
            current_chunk << char
          elsif char_is_chinese == is_chinese
            current_chunk << char
          else
            chunk_str = current_chunk.join
            if is_chinese
              pinyin_results.concat(get_pinyin_elements(instance, chunk_str))
            else
              pinyin_results << Element.new(chunk_str, chunk_str)
            end
            current_chunk.clear
            is_chinese = char_is_chinese
            current_chunk << char
          end
        end

        if !current_chunk.empty?
          chunk_str = current_chunk.join
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
    if LibPinyin.pinyin_phrase_segment(instance, han_text)
      return extract_pinyin_elements_from_instance(instance)
    end

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
      unless LibPinyin.pinyin_get_phrase_token(instance, i, out token)
        next
      end

      if token == 0 # null_token
        next
      end

      # Get the original phrase characters
      phrase_str = ""
      if LibPinyin.pinyin_token_get_phrase(instance, token, nil, pointerof(phrase_str_ptr))
        phrase_str = String.new(phrase_str_ptr)
        LibGLib.g_free(phrase_str_ptr.as(Void*))
      end

      if phrase_str.empty?
        next
      end

      # Check if the token has any pronunciation
      if LibPinyin.pinyin_token_get_n_pronunciation(instance, token, out num_pron) && num_pron > 0
        keys_array = LibGLib.g_array_new(0, 0, 2)
        begin
          if LibPinyin.pinyin_token_get_nth_pronunciation(instance, token, 0, keys_array)
            garray = keys_array.value
            chewing_keys = garray.data.as(UInt16*)

            chars = phrase_str.chars
            (0...garray.len).each do |k|
              key_ptr = chewing_keys + k
              char_str = chars[k]?.try(&.to_s) || ""
              
              if LibPinyin.pinyin_get_pinyin_string(instance, key_ptr, out pinyin_str_ptr)
                pinyin_str = String.new(pinyin_str_ptr)
                LibGLib.g_free(pinyin_str_ptr.as(Void*))
                results << Element.new(char_str, pinyin_str)
              else
                results << Element.new(char_str, char_str)
              end
            end
          else
            # Fallback to raw characters without Pinyin if pronunciation retrieval failed
            phrase_str.each_char do |c|
              results << Element.new(c.to_s, c.to_s)
            end
          end
        ensure
          LibGLib.g_array_free(keys_array, 1)
        end
      else
        # Fallback to characters if there are no pronunciations
        phrase_str.each_char do |c|
          results << Element.new(c.to_s, c.to_s)
        end
      end
    end

    results
  end
end
