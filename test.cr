require "./src/pinyin"

tests = [
  "你今天来的目的是什么",
  "你了解什么是网红吗",
  "北京朝阳区的朝阳真美",
  "你好，世界！ Hello World!",
]
puts "Testing Pinyin.to_pinyin..."
begin
  # Globally set the user directory
  Pinyin.user_dir = "/tmp/pinyin-cr-custom-confs"
  puts "Globally configured Pinyin.user_dir to: '#{Pinyin.user_dir}'"

  tests.each do |test_str|
    result = Pinyin.to_pinyin(test_str)
    puts "Result for '#{test_str}': '#{result}'"

    elements = Pinyin.to_pinyin_array(test_str)
    elements.each do |el|
      puts "Text: '#{el.text}' => Pinyin: '#{el.pinyin}'"
    end
  end
rescue ex : Exception
  puts "Error: #{ex.message}"
  puts ex.backtrace.join("\n")
end
