require "./src/pinyin-cr"

def test_with_options(text : String, flags : UInt32)
  system_dir = "/usr/lib/x86_64-linux-gnu/libpinyin/data"
  user_dir = "/tmp/pinyin-cr-custom-confs"

  Dir.mkdir_p(user_dir) unless Dir.exists?(user_dir)
  user_conf_path = File.join(user_dir, "user.conf")
  unless File.exists?(user_conf_path)
    File.write(user_conf_path, "")
  end

  context = LibPinyin.pinyin_init(system_dir, user_dir)
  if context.nil?
    raise "Failed to initialize context"
  end

  begin
    # Set the options
    LibPinyin.pinyin_set_options(context, flags)

    instance = LibPinyin.pinyin_alloc_instance(context)
    if instance.nil?
      raise "Failed to allocate instance"
    end

    begin
      # Use Pinyin's to_pinyin_array logic or just call it directly with our modified instance
      # Since get_pinyin_elements is private, let's just do it directly.
      LibPinyin.pinyin_reset(instance)
      if LibPinyin.pinyin_phrase_segment(instance, text)
        LibPinyin.pinyin_get_n_phrase(instance, out num_phrases)
        (0...num_phrases).each do |i|
          LibPinyin.pinyin_get_phrase_token(instance, i, out token)
          next if token == 0
          
          phrase_str_ptr = Pointer(LibC::Char).null
          phrase_str = ""
          if LibPinyin.pinyin_token_get_phrase(instance, token, nil, pointerof(phrase_str_ptr))
            phrase_str = String.new(phrase_str_ptr)
            LibGLib.g_free(phrase_str_ptr.as(Void*))
          end

          if LibPinyin.pinyin_token_get_n_pronunciation(instance, token, out num_pron) && num_pron > 0
            keys_array = LibGLib.g_array_new(0, 0, 2)
            if LibPinyin.pinyin_token_get_nth_pronunciation(instance, token, 0, keys_array)
              garray = keys_array.value
              chewing_keys = garray.data.as(UInt16*)
              (0...garray.len).each do |k|
                key_ptr = chewing_keys + k
                if LibPinyin.pinyin_get_pinyin_string(instance, key_ptr, out pinyin_str_ptr)
                  pinyin_str = String.new(pinyin_str_ptr)
                  LibGLib.g_free(pinyin_str_ptr.as(Void*))
                  puts "  Key: #{k} -> Pinyin string: '#{pinyin_str}'"
                else
                  puts "  Key: #{k} -> Failed to get pinyin string"
                end
              end
            end
            LibGLib.g_array_free(keys_array, 1)
          end
        end
      else
        puts "  Phrase segment failed"
      end
    ensure
      LibPinyin.pinyin_free_instance(instance)
    end
  ensure
    LibPinyin.pinyin_fini(context)
  end
end

puts "1. Default / IS_PINYIN only (2)"
test_with_options("北京大学", 2u32)

puts "\n2. IS_PINYIN | USE_TONE (2 | 32 = 34)"
test_with_options("北京大学", 34u32)

puts "\n3. IS_PINYIN | FORCE_TONE (2 | 64 = 66)"
test_with_options("北京大学", 66u32)

puts "\n4. IS_PINYIN | USE_TONE | FORCE_TONE (2 | 32 | 64 = 98)"
test_with_options("北京大学", 98u32)
