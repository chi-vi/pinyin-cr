require "./spec_helper"

describe Pinyin do
  it "converts a simple Chinese phrase to Pinyin string" do
    Pinyin.to_pinyin("北京大学").should eq("bei jing da xue")
  end

  it "converts mixed Chinese and English text" do
    Pinyin.to_pinyin("你好, World!").should eq("ni hao , World!")
  end

  it "converts mixed text with full-width Chinese punctuation" do
    Pinyin.to_pinyin("你好，世界！ Hello World!").should eq("ni hao ， shi jie ！ Hello World!")
  end

  it "supports custom separators" do
    Pinyin.to_pinyin("北京大学", separator: "-").should eq("bei-jing-da-xue")
  end

  describe "global configuration" do
    it "allows setting and getting the user_dir module variable" do
      old_dir = Pinyin.user_dir
      begin
        Pinyin.user_dir = "/tmp/pinyin-cr-custom-spec-dir"
        Pinyin.user_dir.should eq("/tmp/pinyin-cr-custom-spec-dir")
      ensure
        Pinyin.user_dir = old_dir
      end
    end
  end

  describe ".to_pinyin_array" do
    it "converts Chinese text into an array of elements mapping characters to Pinyins" do
      elements = Pinyin.to_pinyin_array("北京大学")
      elements.size.should eq(4)
      elements[0].text.should eq("北")
      elements[0].pinyin.should eq("bei")
      elements[1].text.should eq("京")
      elements[1].pinyin.should eq("jing")
      elements[2].text.should eq("大")
      elements[2].pinyin.should eq("da")
      elements[3].text.should eq("学")
      elements[3].pinyin.should eq("xue")
    end

    it "maps non-Chinese characters to elements with original text as pinyin" do
      elements = Pinyin.to_pinyin_array("你好，World!")
      # Should be: 你, 好, ，World! (3 blocks)
      elements.size.should eq(3)
      elements[0].text.should eq("你")
      elements[0].pinyin.should eq("ni")
      elements[1].text.should eq("好")
      elements[1].pinyin.should eq("hao")
      elements[2].text.should eq("，World!")
      elements[2].pinyin.should eq("，World!")
    end
  end
end
