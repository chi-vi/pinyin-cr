require "./src/pinyin"

puts "Testing Pinyin.to_pinyin..."
begin
  # Globally set the user directory
  Pinyin.user_dir = "/tmp/pinyin-cr-custom-confs"
  puts "Globally configured Pinyin.user_dir to: '#{Pinyin.user_dir}'"

  result = Pinyin.to_pinyin("北京大学")
  puts "Result for '北京大学': '#{result}'"

  result2 = Pinyin.to_pinyin("你好，世界！ Hello World!")
  puts "Result for '你好，世界！ Hello World!': '#{result2}'"

  puts "\nTesting Pinyin.to_pinyin_array..."
  elements = Pinyin.to_pinyin_array("北京大学，你好！ Hello!")
  elements.each do |el|
    puts "Text: '#{el.text}' => Pinyin: '#{el.pinyin}'"
  end
rescue ex : Exception
  puts "Error: #{ex.message}"
  puts ex.backtrace.join("\n")
end
