require "./lib_glib"

@[Link("pinyin")]
lib LibPinyin
  type PinyinContextT = Void*
  type PinyinInstanceT = Void*
  alias PhraseTokenT = UInt32

  enum FullPinyinScheme
    FULL_PINYIN_HANYU = 1
    FULL_PINYIN_LUOMA = 2
    FULL_PINYIN_SECONDARY_ZHUYIN = 3
    FULL_PINYIN_DEFAULT = 1
  end

  fun pinyin_init(systemdir : LibC::Char*, userdir : LibC::Char*) : PinyinContextT
  fun pinyin_fini(context : PinyinContextT) : Void
  fun pinyin_set_options(context : PinyinContextT, options : UInt32) : Bool


  fun pinyin_load_phrase_library(context : PinyinContextT, index : UInt8) : Bool
  fun pinyin_unload_phrase_library(context : PinyinContextT, index : UInt8) : Bool

  fun pinyin_alloc_instance(context : PinyinContextT) : PinyinInstanceT
  fun pinyin_free_instance(instance : PinyinInstanceT) : Void

  fun pinyin_phrase_segment(instance : PinyinInstanceT, sentence : LibC::Char*) : Bool
  fun pinyin_get_n_phrase(instance : PinyinInstanceT, num : LibC::UInt*) : Bool
  fun pinyin_get_phrase_token(instance : PinyinInstanceT, index : LibC::UInt, token : PhraseTokenT*) : Bool

  fun pinyin_token_get_phrase(instance : PinyinInstanceT, token : PhraseTokenT, len : LibC::UInt*, utf8_str : LibC::Char**) : Bool
  fun pinyin_token_get_n_pronunciation(instance : PinyinInstanceT, token : PhraseTokenT, num : LibC::UInt*) : Bool
  fun pinyin_token_get_nth_pronunciation(instance : PinyinInstanceT, token : PhraseTokenT, nth : LibC::UInt, keys : LibGLib::GArrayStruct*) : Bool

  fun pinyin_get_pinyin_string(instance : PinyinInstanceT, key : UInt16*, utf8_str : LibC::Char**) : Bool
  fun pinyin_reset(instance : PinyinInstanceT) : Bool
end
